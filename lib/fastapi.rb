require 'oj'
require 'active_record'
require 'active_support'
require 'fastapi/extension'
require 'fastapi/comparison'
require 'fastapi/conversions'
require 'fastapi/sql'
require 'fastapi/spoof'
require 'fastapi/utilities'

module FastAPI
  Oj.default_options = { mode: :compat }

  class Wrapper
    include FastAPI::Utilities

    def initialize(model)
      @model = model
      @data = nil
      @metadata = nil
      @whitelist_fields = []
    end

    def inspect
      "<#{self.class}: #{@model}>"
    end

    # Create and execute an optimized SQL query based on specified filters
    #
    # @param fields [Array] an array containing fields to whitelist for the SQL query. Can also pass in fields as arguments.
    # @return [FastAPI] the current instance
    def whitelist(*fields)
      @whitelist_fields.concat([fields].flatten)

      self
    end

    # Create and execute an optimized SQL query based on specified filters
    #
    # @param filters [Hash] a hash containing the intended filters
    # @param meta [Hash] a hash containing custom metadata
    # @return [FastAPI] the current instance
    def filter(filters = {}, meta = {}, safe = false)
      results = fastapi_query(filters, safe)

      @metadata = results.slice(:total, :offset, :count, :error).merge(meta)
      @data     = results[:data]

      self
    end

    # Create and execute an optimized SQL query based on specified filters.
    #   Runs through mode fastapi_safe_fields list
    #
    # @param filters [Hash] a hash containing the intended filters
    # @param meta [Hash] a hash containing custom metadata
    # @return [FastAPI] the current instance
    def safe_filter(filters = {}, meta = {})
      filter(filters, meta, true)
    end

    # Create and execute an optimized SQL query based on specified object id.
    # Provides customized error response if not found.
    #
    # @param id [Integer] the id of the object to retrieve
    # @param meta [Hash] a hash containing custom metadata
    # @return [FastAPI] the current instance
    def fetch(id, meta = {})
      id_column_name = @model.primary_key.to_sym

      filter({ id_column_name => id }, meta)

      if @metadata[:total].zero?
        @metadata[:error] = { message: "#{@model} with #{id_column_name}: #{id} does not exist" }
      end

      self
    end

    # Returns the data from the most recently executed `filter` or `fetch` call.
    #
    # @return [Array] available data
    def data
      @data
    end

    # Returns JSONified data from the most recently executed `filter` or `fetch` call.
    #
    # @return [String] available data in JSON format
    def data_json
      Oj.dump(@data)
    end

    # Returns the metadata from the most recently executed `filter` or `fetch` call.
    #
    # @return [Hash] available metadata
    def meta
      @metadata
    end

    # Returns JSONified metadata from the most recently executed `filter` or `fetch` call.
    #
    # @return [String] available metadata in JSON format
    def meta_json
      Oj.dump(@metadata)
    end

    # Returns both the data and metadata from the most recently executed `filter` or `fetch` call.
    #
    # @return [Hash] available data and metadata
    def to_hash
      { meta: @metadata, data: @data }
    end

    # Intended to return the final API response
    #
    # @return [String] JSON data and metadata
    def response
      Oj.dump(to_hash)
    end

    # Spoofs data from Model
    #
    # @return [String] JSON data and metadata
    def spoof(data = [], meta = {})
      FastAPI::Spoof.new(data, meta).spoof
    end

    def spoof!(data, meta = {})
      FastAPI::Spoof.new(data, meta, @whitelist_fields).spoof!
    end

    # Returns a JSONified string representing a rejected API response with invalid fields parameters
    #
    # @param fields [Hash] Hash containing fields and their related errors
    # @return [String] JSON data and metadata, with error
    def invalid(fields)
      Oj.dump(
        meta: {
          total: 0,
          offset: 0,
          count: 0,
          error: {
            message: 'invalid',
            fields: fields
          }
        },
        data: []
      )
    end

    # Returns a JSONified string representing a standardized empty API response, with a provided error message
    #
    # @param message [String] Error message to be used in response
    # @return [String] JSON data and metadata, with error
    def reject(message = 'Access denied')
      Oj.dump(
        meta: {
          total: 0,
          offset: 0,
          count: 0,
          error: {
            message: message
          }
        },
        data: []
      )
    end

    private

    def error(offset, message)
      { data: [], total: 0, count: 0, offset: offset, error: { message: message } }
    end

    def fastapi_query(filters = {}, safe = false)

      unless ActiveRecord::ConnectionAdapters.constants.include?(:PostgreSQLAdapter) &&
          ActiveRecord::Base.connection.instance_of?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
        fail 'FastAPI only supports PostgreSQL at this time.'
      end

      offset = filters.delete(:__offset).try(:to_i) || 0
      cnt    = filters.delete(:__count).try(:to_i) || 500
      count  = clamp(cnt, 1, 500)

      begin
        parsed_filters = parse_filters(filters, safe)
        prepared_data = FastAPI::SQL.new(parsed_filters, offset, count, @model, @whitelist_fields)
      rescue StandardError => exception
        return error(offset, exception.message)
      end

      model_lookup = prepared_data[:models].each_with_object({}) do |(key, model), lookup|
        columns = model.columns_hash
        lookup[key] = {
          model: model,
          fields: model.fastapi_fields_sub,
          types: model.fastapi_fields_sub.map { |field| columns[field.to_s].try(:type) }
        }
      end

      begin
        count_result = ActiveRecord::Base.connection.execute(prepared_data[:count_query])
        result = ActiveRecord::Base.connection.execute(prepared_data[:query])
      rescue StandardError
        return error(offset, 'Query failed')
      end

      total_size = count_result.values.size > 0 ? count_result.values[0][0].to_i : 0

      fields = result.fields
      rows   = result.values

      dataset = rows.each_with_object([]) do |row, data|
        datum = row.each_with_object({}).with_index do |(val, current), index|
          field = fields[index]
          split_index = field.rindex('__')

          if field[0..7] == '__many__'

            field     = field[8..-1]
            field_sym = field.to_sym
            model     = model_lookup[field_sym]

            current[field_sym] = parse_many(val, model[:fields], model[:types])

          elsif split_index

            obj_name = field[0..split_index - 1].to_sym
            field    = field[split_index + 2..-1]
            model    = model_lookup[obj_name][:model]

            current[obj_name] ||= {}

            model_field = model.columns_hash[field]
            current[obj_name][field.to_sym] = FastAPI::Conversions.convert_type(val, model_field.type, model_field)

          elsif @model.columns_hash[field]
            model_field = @model.columns_hash[field]
            current[field.to_sym] = FastAPI::Conversions.convert_type(val, model_field.type, model_field)
          end
        end
        data << datum
      end
      { data: dataset, total: total_size, count: dataset.size, offset: offset, error: nil }
    end

    def parse_many(str, fields, types)
      Oj.load(str).map do |row|
        row.values.each_with_object({}).with_index do |(value, values), index|
          values[fields[index]] = FastAPI::Conversions.convert_type(value, types[index])
        end
      end
    end

    def parse_filters(filters, safe = false, model = nil)
      self_obj = model ? model : @model
      self_string_table = model ? "__#{model.table_name}" : @model.table_name

      filters = filters.with_indifferent_access

      # if we're at the top level...
      if model.nil?
        if safe
          filters.keys.each do |key|

            found_index = key.to_s.rindex('__')
            key_root = (found_index ? key.to_s[0..found_index] : key).to_sym

            if [:__order, :__offset, :__count, :__params].exclude?(key) && self_obj.fastapi_filters_whitelist.exclude?(key_root)
              fail %(Filter "#{key}" not supported.)
            end

          end
        end

        filters = @model.fastapi_filters.clone.merge(filters).with_indifferent_access
      end

      params = filters.key?(:__params) ? filters.delete(:__params) : []

      filters.keys.each do |key|
        key = key.to_sym

        next if [:__order, :__offset, :__count, :__params].include?(key)

        found_index = key.to_s.rindex('__')
        key_root = found_index.nil? ? key : key.to_s[0...found_index].to_sym

        unless self_obj.column_names.include?(key_root.to_s)
          if !model.nil? || !(@model.reflect_on_all_associations(:has_many).map(&:name).include?(key_root) ||
              @model.reflect_on_all_associations(:belongs_to).map(&:name).include?(key_root) ||
              @model.reflect_on_all_associations(:has_one).map(&:name).include?(key_root))
            fail %(Filter "#{key}" not supported)
          end
        end
      end

      filter_array = []
      filter_has_many = {}
      filter_belongs_to = {}

      order = nil
      order_has_many = {}
      order_belongs_to = {}

      # get the order first
      if filters.key?(:__order)

        order = filters.delete(:__order)

        if order.is_a?(String)
          order = order.split(',')
          if order.size < 2
            order << 'ASC'
          end
        elsif order.is_a?(Array)
          order = order.map(&:to_s)
          while order.size < 2
            order << ''
          end
        else
          order = ['', '']
        end

        order[1] = 'ASC' if %w(ASC DESC).exclude?(order[1])

        if model.nil? && @model.fastapi_custom_order.key?(order[0].to_sym)

          order[0] = @model.fastapi_custom_order[order[0].to_sym].gsub('self.', "#{self_string_table}.")

          if params.is_a?(Array)
            order[0].gsub!(/\$params\[([\w-]+)\]/) { ActiveRecord::Base.connection.quote(params[Regexp.last_match[1].to_i].to_s) }
          else
            order[0].gsub!(/\$params\[([\w-]+)\]/) { ActiveRecord::Base.connection.quote(params[Regexp.last_match[1]].to_s) }
          end

          order[0] = "(#{order[0]})"
          order = order.join(' ')
        else

          if self_obj.column_names.exclude?(order[0])
            order = nil
          else
            order[0] = %("#{self_string_table}"."#{order[0]}")
            order = order.join(' ')
          end
        end
      end

      filters.each do |key, data|

        key = key.to_sym
        field = key.to_s

        if field.rindex('__').nil?
          comparator = 'is'
        else
          comparator = field[(field.rindex('__') + 2)..-1]
          field = field[0...field.rindex('__')]

          next if FastAPI::Comparison.invalid_comparator?(comparator)
        end

        if model.nil? && self_obj.reflect_on_all_associations(:has_many).map(&:name).include?(key)

          filter_result        = parse_filters(data, safe, field.singularize.classify.constantize)
          filter_has_many[key] = filter_result[:main]
          order_has_many[key]  = filter_result[:main_order]

        elsif model.nil? && (self_obj.reflect_on_all_associations(:belongs_to).map(&:name).include?(key) ||
                             self_obj.reflect_on_all_associations(:has_one).map(&:name).include?(key))

          filter_result          = parse_filters(data, safe, field.singularize.classify.constantize)
          filter_belongs_to[key] = filter_result[:main]
          order_belongs_to[key]  = filter_result[:main_order]

        elsif self_obj.column_names.include?(field)

          base_field   = %("#{self_string_table}"."#{field}")
          filter_array << Comparison.new(comparator, data, base_field, self_obj.columns_hash[field].type)

        end
      end

      {
        main: filter_array,
        main_order: order,
        has_many: filter_has_many,
        has_many_order: order_has_many,
        belongs_to: filter_belongs_to,
        belongs_to_order: order_belongs_to
      }
    end
  end
end
