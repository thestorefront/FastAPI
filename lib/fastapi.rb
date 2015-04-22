require 'oj'
require 'fastapi/active_record_extension'

class FastAPI

  @@result_types = { single: 0, multiple: 1 }

  @@api_comparator_list = %w(
    is
    not
    gt
    gte
    lt
    lte
    in
    not_in
    contains
    icontains
    is_null
    not_null
  )

  def initialize(model)
    @model = model
    @data = nil
    @metadata = nil
    @result_type = 0
    @whitelist_fields = []
  end

  def inspect
    "<#{self.class}: #{@model}>"
  end

  # Create and execute an optimized SQL query based on specified filters
  #
  # @param fields [Array] an array containing fields to whitelist for the SQL query. Can also pass in fields as arguments.
  # @return [FastAPI] the current instance
  def whitelist(fields = [])
    @whitelist_fields.concat(fields)

    self
  end

  # Create and execute an optimized SQL query based on specified filters
  #
  # @param filters [Hash] a hash containing the intended filters
  # @param meta [Hash] a hash containing custom metadata
  # @return [FastAPI] the current instance
  def filter(filters = {}, meta = {}, safe = false)
    result = fastapi_query(filters, safe)

    @metadata    = meta.merge(result.slice(:total, :offset, :count, :error))
    @data        = result[:data]
    @result_type = @@result_types[:multiple]

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
    filter({ id: id }, meta)

    if @metadata[:total].zero?
      @metadata[:error] = { message: "#{@model} id does not exist" }
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
    Oj.dump(@data, mode: :compat)
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
    Oj.dump(@metadata, mode: :compat)
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
    Oj.dump(self.to_hash, mode: :compat)
  end

  # Spoofs data from Model
  #
  # @return [String] JSON data and metadata
  def spoof(data = [], meta = {})
    meta[:total]  ||= data.count
    meta[:count]  ||= data.count
    meta[:offset] ||= 0

    Oj.dump({ meta: meta, data: data }, mode: :compat)
  end

  # Returns a JSONified string representing a rejected API response with invalid fields parameters
  #
  # @param fields [Hash] Hash containing fields and their related errors
  # @return [String] JSON data and metadata, with error
  def invalid(fields)
    Oj.dump({
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
    }, mode: :compat)
  end

  # Returns a JSONified string representing a standardized empty API response, with a provided error message
  #
  # @param message [String] Error message to be used in response
  # @return [String] JSON data and metadata, with error
  def reject(message = 'Access denied')
    Oj.dump({
      meta: {
        total: 0,
        offset: 0,
        count: 0,
        error: {
          message: message.to_s
        }
      },
      data: []
    }, mode: :compat)
  end

  private

  def clamp(value, min, max)
    [min, value, max].sort[1]
  end

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
      prepared_data = api_generate_sql(filters, offset, count, safe)
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
    rescue
      error(offset, 'Query failed')
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

          current[obj_name][field.to_sym] = api_convert_type(val,
            model.columns_hash[field].type,
            (model.columns_hash[field].respond_to?('array') && model.columns_hash[field].array))

        elsif @model.columns_hash[field]

          current[field.to_sym] = api_convert_type(val,
            @model.columns_hash[field].type,
            (@model.columns_hash[field].respond_to?('array') && @model.columns_hash[field].array))
        end
      end
      data << datum
    end
    { data: dataset, total: total_size, count: dataset.size, offset: offset, error: nil }
  end

  def parse_many(str, fields, types)
    Oj.load(str).map do |row|
      row.values.each_with_object({}).with_index do |(value, values), index|
        values[fields[index]] = api_convert_type(value, types[index])
      end
    end
  end

  def api_comparison(comparator, value, field, type, is_array)
    field_string = is_array ? "ANY(#{field})" : field

    if comparator == 'is'

      ActiveRecord::Base.connection.quote(value.to_s) + ' = ' + field_string

    elsif comparator == 'not'

      ActiveRecord::Base.connection.quote(value.to_s) + ' <> ' + field_string

    elsif comparator == 'gt'

      ActiveRecord::Base.connection.quote(value.to_s) + ' < ' + field_string

    elsif comparator == 'gte'

      ActiveRecord::Base.connection.quote(value.to_s) + ' <= ' + field_string

    elsif comparator == 'lt'

      ActiveRecord::Base.connection.quote(value.to_s) + ' > ' + field_string

    elsif comparator == 'lte'

      ActiveRecord::Base.connection.quote(value.to_s) + ' >= ' + field_string

    elsif comparator == 'in' || comparator == 'not_in'

      unless value.is_a?(Array)

        if value.is_a?(Range)
          value = value.to_a
        else
          value = [value.to_s]
        end
      end

      if is_array

        type_convert = {
          boolean: '::boolean',
          integer: '::integer',
          float: '::float',
          string: '::varchar'
        }[type]

        type_convert = '::text' if type.nil?

        if comparator == 'in'
          'ARRAY[' + (value.map { |val| ActiveRecord::Base.connection.quote(val.to_s) }).join(',') + ']' + type_convert + '[] && ' + field
        else
          'NOT ARRAY[' + (value.map { |val| ActiveRecord::Base.connection.quote(val.to_s) }).join(',') + ']' + type_convert + '[] && ' + field
        end
      else

        if comparator == 'in'
          field + ' IN(' + (value.map { |val| ActiveRecord::Base.connection.quote(val.to_s) }).join(',') + ')'
        else
          field + ' NOT IN(' + (value.map { |val| ActiveRecord::Base.connection.quote(val.to_s) }).join(',') + ')'
        end
      end

    elsif comparator == 'contains'

      field_string + ' LIKE \'%\' || ' + ActiveRecord::Base.connection.quote(value.to_s) + ' || \'%\''

    elsif comparator == 'icontains'

      field_string + ' ILIKE \'%\' || ' + ActiveRecord::Base.connection.quote(value.to_s) + ' || \'%\''

    elsif comparator == 'is_null'

      "#{field_string} IS NULL"

    elsif comparator == 'not_null'

      "#{field_string} IS NOT NULL"
    end
  end

  def api_convert_type(val, type, is_array = false)
    if val && is_array
      Oj.load(val).map { |inner_value| api_convert_value(inner_value, type) }
    else
      api_convert_value(val, type)
    end
  end

  def api_convert_value(val, type)
    if val
      case type
      when :integer
        val.to_i
      when :float
        val.to_f
      when :boolean
        { 't' => true, 'f' => false }[val]
      else
        val
      end
    end
  end

  def parse_filters(filters, safe = false, model = nil)

    self_obj = model ? model : @model
    self_string_table = model ? "__#{model.to_s.tableize}" : @model.to_s.tableize

    filters = filters.clone.symbolize_keys
    # if we're at the top level...
    if model.nil?

      if safe
        filters.each do |key, value|
          found_index = key.to_s.rindex('__')
          key_root = found_index ? key.to_s[0..found_index].to_sym : key

          if [:__order, :__offset, :__count].exclude?(key) && self_obj.fastapi_filters_whitelist.exclude?(key_root)
            fail %(Filter "#{key}" not supported.)
          end
        end
      end

      filters = @model.fastapi_filters.clone.merge(filters)
    end

    params = filters.has_key?(:__params) ? [*filters.delete(:__params)] : []
    filters[:__order] ||= [:created_at, :DESC]

    filters.each do |key, value|

      next if [:__order, :__offset, :__count, :__params].include?(key)

      found_index = key.to_s.rindex('__')
      key_root = found_index.nil? ? key : key.to_s[0...found_index].to_sym

      if !self_obj.column_names.include?(key_root.to_s)
        if !model.nil? || !(@model.reflect_on_all_associations(:has_many).map(&:name).include?(key_root)   ||
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

    if filters.has_key?(:__order)

      value = filters.delete(:__order)

      order = value.clone()

      if order.is_a?(String)
        order = order.split(',')
        if order.size < 2
          order << 'ASC'
        end
      elsif order.is_a?(Array)
        order = order.map { |v| v.to_s }
        while order.size < 2
          order << ''
        end
      else
        order = ['', '']
      end

      order[1] = 'ASC' if ['ASC', 'DESC'].exclude?(order[1])

      if model.nil? && @model.fastapi_custom_order.has_key?(order[0].to_sym)

        order[0] = @model.fastapi_custom_order[order[0].to_sym].gsub('self.', self_string_table + '.')

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
          order[0] = "#{self_string_table}.#{order[0]}"
          order = order.join(' ')
        end
      end
    end

    if filters.size > 0

      filters.each do |key, data|
        field = key.to_s

        if field.rindex('__').nil?
          comparator = 'is'
        else

          comparator = field[(field.rindex('__') + 2)..-1]
          field = field[0...field.rindex('__')]

          if @@api_comparator_list.exclude?(comparator)
            next # skip dis bro
          end
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

          base_field   = "#{self_string_table}.#{field}"
          field_string = base_field
          is_array     = false

          if self_obj.columns_hash[field].respond_to?('array') && self_obj.columns_hash[field].array == true
            field_string = "ANY(#{field_string})"
            is_array = true
          end

          if self_obj.columns_hash[field].type == :boolean

            # if data is not a boolean
            if !!data != data
              data = ['f', 'false'].include?(data) ? false : true
            end

            if comparator == 'is'
              filter_array << "#{data.to_s.upcase} = #{field_string}"
            elsif comparator == 'not'
              filter_array << "NOT #{data.to_s.upcase} = #{field_string}"
            end

          elsif data == nil && comparator != 'is_null' && comparator != 'not_null'
            if comparator == 'is'
              filter_array << "#{field_string} IS NULL"
            elsif comparator == 'not'
              filter_array << "#{field_string} IS NOT NULL"
            end

          elsif data.is_a?(Range) && comparator == 'is'
            filter_array << "#{ActiveRecord::Base.connection.quote(data.first.to_s)} <= #{field_string}"
            filter_array << "#{ActiveRecord::Base.connection.quote(data.last.to_s)} >= #{field_string}"
          else
            filter_array << api_comparison(comparator, data, base_field, self_obj.columns_hash[field].type, is_array)
          end
        end
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

  def api_generate_sql(filters, offset, count, safe = false)

    filters = parse_filters(filters, safe)

    belongs  = []
    has_many = []

    model_lookup = {}

    filter_fields = []
    filter_fields.concat(@model.fastapi_fields)
    filter_fields.concat(@whitelist_fields)

    fields = filter_fields.each_with_object([]) do |field, field_list|
      if @model.reflect_on_all_associations(:belongs_to).map(&:name).include?(field)
        class_name = @model.reflect_on_association(field).options[:class_name]

        if class_name
          model = class_name.constantize
        else
          model = field.to_s.classify.constantize
        end

        model_lookup[field] = model
        belongs << { model: model, alias: field, type: :belongs_to }

      elsif @model.reflect_on_all_associations(:has_one).map(&:name).include?(field)

        class_name = @model.reflect_on_association(field).options[:class_name]

        if class_name
          model = class_name.constantize
        else
          model = field.to_s.classify.constantize
        end

        model_lookup[field] = model

        belongs << { model: model, alias: field, type: :has_one }

      elsif @model.reflect_on_all_associations(:has_many).map(&:name).include?(field)

        model = field.to_s.singularize.classify.constantize
        model_lookup[field] = model
        has_many << model

      elsif @model.column_names.include?(field.to_s)

        field_list << field
      end
    end

    self_string = @model.to_s.tableize.singularize
    self_string_table = @model.to_s.tableize

    # Base fields
    field_list = fields.each_with_object([]) do |field, list|
      if @model.columns_hash[field.to_s].array
        list << "ARRAY_TO_JSON(#{self_string_table}.#{field}) AS #{field}"
      else
        list << "#{self_string_table}.#{field} AS #{field}"
      end
    end

    # Belongs fields (1 to 1)
    joins = belongs.each_with_object([]) do |model_data, join_list|

      model_string_table       = model_data[:model].to_s.tableize
      model_string_table_alias = model_data[:alias].to_s.pluralize

      model_string_field  = model_data[:alias].to_s
      singular_self_table = self_string_table.singularize

      model_data[:model].fastapi_fields_sub.each do |field|
        if model_data[:model].columns_hash[field.to_s].array
          field_list << "ARRAY_TO_JSON(#{model_string_table_alias}.#{field}) AS #{model_string_field}__#{field}"
        else
          field_list << "#{model_string_table_alias}.#{field} AS #{model_string_field}__#{field}"
        end
      end

      # fields
      if model_data[:type] == :belongs_to
        # joins
        join_list << "LEFT JOIN #{model_string_table} AS #{model_string_table_alias} " \
                       "ON #{model_string_table_alias}.id = #{self_string_table}.#{model_string_field}_id"
      elsif model_data[:type] == :has_one
        join_list << "LEFT JOIN #{model_string_table} AS #{model_string_table_alias} " \
                       "ON #{model_string_table_alias}.#{singular_self_table}_id = #{self_string_table}.id"
      end
    end

    # Many fields (1 to many)
    has_many.each do |model|

      model_string_table = model.to_s.tableize
      model_symbol = model_string_table.to_sym

      model_fields = model.fastapi_fields_sub.each_with_object([]) do |field, m_fields|
        m_fields << "__#{model_string_table}.#{field}"
      end

      if filters[:has_many].has_key?(model_symbol)
        if filters[:has_many][model_symbol].count > 0
          has_many_filters = "AND #{filters[:has_many][model_symbol].join(' AND ')}"
        else
          has_many_filters = nil
        end

        if filters[:has_many_order][model_symbol]
          has_many_order = "ORDER BY #{filters[:has_many_order][model_symbol]}"
        else
          has_many_filters = nil
        end
      end

      field_list << [
        "ARRAY_TO_JSON(ARRAY(SELECT ROW(#{model_fields.join(', ')})",
        "FROM #{model_string_table}",
        "AS __#{model_string_table}",
        "WHERE __#{model_string_table}.#{self_string}_id IS NOT NULL",
        "AND __#{model_string_table}.#{self_string}_id",
        "= #{self_string_table}.id",
        has_many_filters,
        has_many_order,
        ")) AS __many__#{model_string_table}"
      ].compact.join(' ')
    end

    filter_string = filters[:main].size > 0 ? "WHERE #{filters[:main].join(' AND ')}" : nil
    order_string  = filters[:main_order] ? "ORDER BY #{filters[:main_order]}" : nil

    {
      query: [
        "SELECT #{field_list.join(', ')}",
        "FROM #{self_string_table}",
        joins.join(' '),
        filter_string,
        order_string,
        "LIMIT #{count}",
        "OFFSET #{offset}"
      ].compact.join(' '),
      count_query: [
        "SELECT COUNT(id) FROM #{self_string_table}",
        filter_string
      ].compact.join(' '),
      models: model_lookup
    }
  end
end
