require 'oj'
require 'fastapi/active_record_extension.rb'

class FastAPI

  @@result_types = {
    single: 0,
    multiple: 1,
  }

  @@api_comparator_list = [
    'is',
    'not',
    'gt',
    'gte',
    'lt',
    'lte',
    'in',
    'not_in',
    'contains',
    'icontains',
    'is_null',
    'not_null',
  ]

  def initialize(model)
    @model = model
    @data = nil
    @metadata = nil
    @has_results = false
    @result_type = 0
  end

  def inspect
    "<#{self.class}: #{@model}>"
  end


  # Create and execute an optimized SQL query based on specified filters
  #
  # @param filters [Hash] a hash containing the intended filters
  # @param meta [Hash] a hash containing custom metadata
  # @return [FastAPI] the current instance
  def filter(filters = {}, meta = {})

    result = fastapi_query(filters)

    metadata = {}

    meta.each do |key, value|
      metadata[key] = value
    end

    metadata[:total] = result[:total]
    metadata[:offset] = result[:offset]
    metadata[:count] = result[:count]
    metadata[:error] = result[:error]

    @metadata = metadata
    @data = result[:data]

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

    result = fastapi_query(filters, true)

    metadata = {}

    meta.each do |key, value|
      metadata[key] = value
    end

    metadata[:total] = result[:total]
    metadata[:offset] = result[:offset]
    metadata[:count] = result[:count]
    metadata[:error] = result[:error]

    @metadata = metadata
    @data = result[:data]

    @result_type = @@result_types[:multiple]

    self

  end

  # Create and execute an optimized SQL query based on specified object id.
  # Provides customized error response if not found.
  #
  # @param id [Integer] the id of the object to retrieve
  # @param meta [Hash] a hash containing custom metadata
  # @return [FastAPI] the current instance
  def fetch(id, meta = {})

    result = fastapi_query({id: id})

    metadata = {}

    meta.each do |key, value|
      metadata[key] = value
    end

    if result[:total] == 0
      error = @model.to_s + ' id does not exist'
    else
      error = result[:error]
    end

    metadata[:total] = result[:total]
    metadata[:offset] = result[:offset]
    metadata[:count] = result[:count]
    metadata[:error] = error

    @metadata = metadata
    @data = result[:data]

    @result_type = @@result_types[:multiple]

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
    {
      meta: @metadata,
      data: @data
    }
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
  def spoof(data, meta)

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
        error: message.to_s
      },
      data: [],
    }, mode: :compat)
  end

  private

    def fastapi_query(filters = {}, safe = false)

      if (not ActiveRecord::ConnectionAdapters.constants.include? :PostgreSQLAdapter or
      not ActiveRecord::Base.connection.instance_of? ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
        raise 'Fast API only supports PostgreSQL at this time'
      end

      offset = 0
      count = 500
      order = nil

      if filters.has_key? :__offset
        offset = filters[:__offset].to_i
        filters.delete(:__offset)
      end

      if filters.has_key? :__count
        count = [1, [500, filters[:__count].to_i].min].max
        filters.delete(:__count)
      end

      begin
        prepared_data = api_generate_sql(filters, offset, count, safe)
      rescue Exception => error
        return {
          data: [],
          total: 0,
          count: 0,
          offset: offset,
          error: error.message
        }
      end

      model_lookup = {}
      prepared_data[:models].each do |key, model|
        columns_hash = model.columns_hash
        model_lookup[key] = {
          model: model,
          fields: model.fastapi_fields_sub,
          types: model.fastapi_fields_sub.map { |field| (columns_hash.has_key? field.to_s) ? columns_hash[field.to_s].type : nil },
        }
      end

      error = nil

      begin
        count_result = ActiveRecord::Base.connection.execute(prepared_data[:count_query])
        result = ActiveRecord::Base.connection.execute(prepared_data[:query])
      rescue
        return {
          data: [],
          total: 0,
          count: 0,
          offset: offset,
          error: 'Query failed'
        }
      end

      total_size = count_result.values().size > 0 ? count_result.values()[0][0].to_i : 0

      start = Time.now()

      fields = result.fields()
      rows = result.values()

      dataset = Array.new(rows.size)

      rows.each_with_index do |row, index|
        currow = {}
        row.each_with_index do |val, key_index|

          field = fields[key_index]
          split_index = field.rindex('__')

          if field[0..7] == '__many__'

            field = field[8..-1]
            field_sym = field.to_sym
            model = model_lookup[field_sym]

            currow[field_sym] = parse_many(
              val,
              model_lookup[field_sym][:fields],
              model_lookup[field_sym][:types]
            )

          elsif split_index

            obj_name = field[0..split_index - 1].to_sym
            field = field[split_index + 2..-1]
            model = model_lookup[obj_name][:model]

            if !(currow.has_key? obj_name)
              currow[obj_name] = {}
            end

            currow[obj_name][field.to_sym] = api_convert_type(val, model.columns_hash[field].type)

          elsif @model.columns_hash[field]

            currow[field.to_sym] = api_convert_type(val, @model.columns_hash[field].type)

          end

        end

        dataset[index] = currow

      end

      my_end = Time.now()

      # puts dataset.size.to_s + '-length array parsed in ' + (my_end - start).to_s

      {
        data: dataset,
        total: total_size,
        count: dataset.size,
        offset: offset,
        error: nil
      }

    end

    def parse_many(str, fields = [], types = [])

      rows = []
      cur_row = {}
      entry_index = 0

      i = 0
      len = str.length

      i = str.index('(')

      if not i
        return rows
      end

      i = i + 1

      while i < len

        c = str[i]

        if c == ')'

          rows << cur_row
          cur_row = {}
          entry_index = 0
          i = i + 3

        elsif c == '"'

          i = i + 1
          nextIndex = str.index('"', i)

          while str[nextIndex - 1] == '\\'

            j = 1
            while str[nextIndex - j] == '\\'
              j = j + 1
            end

            if j & 1 == 1
              break
            end

            nextIndex = str.index('"', nextIndex + 1)

          end

          cur_row[fields[entry_index]] = api_convert_type(str[i...nextIndex], types[entry_index])
          entry_index = entry_index + 1

          i = nextIndex + 1

        else

          if c == ','
            i = i + 1
          end

          parensIndex = str.index(')', i)
          nextIndex = str.index(',', i)

          if nextIndex.nil? or nextIndex > parensIndex
            nextIndex = parensIndex
          end

          if i == nextIndex
            cur_row[fields[entry_index]] = nil
          else
            cur_row[fields[entry_index]] = api_convert_type(str[i...nextIndex], types[entry_index])
          end

          entry_index = entry_index + 1

          if nextIndex == parensIndex
            rows << cur_row
            cur_row = {}
            entry_index = 0
            i = nextIndex + 3
          else
            i = nextIndex + 1
          end

        end

      end

      rows

    end


    def api_comparison(comparator, value)

      if comparator == 'is'

        ' = ' + ActiveRecord::Base.connection.quote(value.to_s)

      elsif comparator == 'not'

        ' <> ' + ActiveRecord::Base.connection.quote(value.to_s)

      elsif comparator == 'gt'

        ' > ' + ActiveRecord::Base.connection.quote(value.to_s)

      elsif comparator == 'gte'

        ' >= ' + ActiveRecord::Base.connection.quote(value.to_s)

      elsif comparator == 'lt'

        ' < ' + ActiveRecord::Base.connection.quote(value.to_s)

      elsif comparator == 'lte'

        ' <= ' + ActiveRecord::Base.connection.quote(value.to_s)

      elsif comparator == 'in' or comparator == 'not_in'

        if not value.is_a? Array

          if value.is_a? Range
            value = value.to_a
          else
            value = [value.to_s]
          end

        end

        if comparator == 'in'
          ' IN(' + (value.map { |val| ActiveRecord::Base.connection.quote(val.to_s) }).join(',') + ')'
        else
          ' NOT IN(' + (value.map { |val| ActiveRecord::Base.connection.quote(val.to_s) }).join(',') + ')'
        end

      elsif comparator == 'contains'

        ' LIKE \'%\' || ' + ActiveRecord::Base.connection.quote(value.to_s) + ' || \'%\''

      elsif comparator == 'icontains'

        ' ILIKE \'%\' || ' + ActiveRecord::Base.connection.quote(value.to_s) + ' || \'%\''

      elsif comparator == 'is_null'

        ' IS NULL'

      elsif comparator == 'not_null'

        ' IS NOT NULL'

      end

    end

    def api_convert_type(val, type)

      if not val.nil?
        if type == :integer
          val = val.to_i
        elsif type == :float
          val = val.to_f
        elsif type == :boolean
          val = {
            't' => true,
            'f' => false,
          }[val]
        end
      end

      val

    end

    def parse_filters(filters, safe = false, model = nil)

      self_obj = model.nil? ? @model : model
      self_string_table = model.nil? ? @model.to_s.tableize : '__' + model.to_s.tableize

      filters = filters.clone()
      # if we're at the top level...
      if model.nil?

        if safe
          filters.each do |key, value|
            found_index = key.to_s.rindex('__')
            key_root = found_index.nil? ? key : key.to_s[0...found_index].to_sym
            if not [:__order, :__offset, :__count].include? key and not self_obj.fastapi_fields_whitelist.include? key_root
              raise 'Filter "' + key.to_s + '" not supported'
            end
          end
        end

        all_filters = @model.fastapi_filters.clone()

        filters.each do |field, value|
          all_filters[field.to_sym] = value
        end

        filters = all_filters

      end

      if not filters.has_key? :__order
        filters[:__order] = [:created_at, :DESC]
      end


      filters.each do |key, value|
        if [:__order, :__offset, :__count].include? key
          next
        end
        found_index = key.to_s.rindex('__')
        key_root = found_index.nil? ? key : key.to_s[0...found_index].to_sym
        if not self_obj.column_names.include? key_root.to_s
          if not model.nil? or (
            not @model.reflect_on_all_associations(:has_many).map(&:name).include? key_root and
            not @model.reflect_on_all_associations(:belongs_to).map(&:name).include? key_root
          )
            raise 'Filter "' + key.to_s + '" not supported'
          end
        end
      end


      filter_array = []
      filter_has_many = {}

      order = nil
      order_has_many = {}

      if filters.size > 0

        filters.each do |key, value|

          if key == :__order

            if model.nil? and (value.is_a? String or value.is_a? Symbol) and @model.fastapi_custom_order.has_key? value.to_sym

              order = @model.fastapi_custom_order[value.to_sym].gsub('self.', self_string_table + '.')

            else

              order = value.clone()

              if order.is_a? String
                order = order.split(',')
                if order.size < 2
                  order << 'ASC'
                end
              elsif order.is_a? Array
                order = order.map { |v| v.to_s }
                while order.size < 2
                  order << ''
                end
              else
                order = ['', '']
              end

              if not self_obj.column_names.include? order[0]
                order = nil
              else
                order[0] = self_string_table + '.' + order[0]
                if not ['ASC', 'DESC'].include? order[1]
                  order[1] = 'ASC'
                end
                order = order.join(' ')
              end

            end

          else

            field = key.to_s

            if field.rindex('__').nil?
              comparator = 'is'
            else

              comparator = field[(field.rindex('__') + 2)..-1]
              field = field[0...field.rindex('__')]

              if not @@api_comparator_list.include? comparator
                next # skip dis bro
              end

            end

            if model.nil? and self_obj.reflect_on_all_associations(:has_many).map(&:name).include? key

              filter_result = parse_filters(value, safe, field.singularize.classify.constantize)
              # puts filter_result
              filter_has_many[key] = filter_result[:main]
              order_has_many[key] = filter_result[:main_order]

            elsif self_obj.column_names.include? field

              if self_obj.columns_hash[field].type == :boolean

                if !!value != value
                  value = {
                    't' => true,
                    'f' => false
                  }[value]
                end

                if !!value == value

                  if comparator == 'is'
                    filter_array << self_string_table + '.' + field + ' IS ' + value.to_s.upcase
                  elsif comparator == 'not'
                    filter_array << self_string_table + '.' + field + ' IS NOT ' + value.to_s.upcase
                  end

                end

              elsif value == nil and comparator != 'is_null' and comparator != 'not_null'

                if comparator == 'is'
                  filter_array << self_string_table + '.' + field + ' IS NULL'
                elsif comparator == 'not'
                  filter_array << self_string_table + '.' + field + ' IS NOT NULL'
                end

              elsif value.is_a? Range and comparator == 'is'

                filter_array << self_string_table + '.' + field + ' >= ' + ActiveRecord::Base.connection.quote(value.first.to_s)
                filter_array << self_string_table + '.' + field + ' <= ' + ActiveRecord::Base.connection.quote(value.last.to_s)

              else

                filter_array << self_string_table + '.' + field + api_comparison(comparator, value)

              end

            end

          end

        end

      end

      {
        main: filter_array,
        main_order: order,
        has_many: filter_has_many,
        has_many_order: order_has_many
      }

    end

    def api_generate_sql(filters, offset, count, safe = false)

      filters = parse_filters(filters, safe)

      fields = []
      belongs = []
      has_many = []

      model_lookup = {}

      @model.fastapi_fields.each do |field|
        if @model.reflect_on_all_associations(:belongs_to).map(&:name).include? field
          model = field.to_s.classify.constantize
          model_lookup[field] = model
          belongs << model
        elsif @model.reflect_on_all_associations(:has_many).map(&:name).include? field
          model = field.to_s.singularize.classify.constantize
          model_lookup[field] = model
          has_many << model
        elsif @model.column_names.include? field.to_s
          fields << field
        end
      end

      self_string = @model.to_s.tableize.singularize
      self_string_table = @model.to_s.tableize

      field_list = []
      joins = []

      # array_to_string: (ActiveRecord::Base.connection.instance_of? ActiveRecord::ConnectionAdapters::SQLite3Adapter) ? 'GROUP_CONCAT' : 'ARRAY_TO_STRING',

      # Base fields
      fields.each do |field|

        field_string = field.to_s
        field_list << [
          self_string_table,
          '.',
          field_string,
          ' as ',
          field_string
        ].join('')

      end

      # Belongs fields (1 to 1)
      belongs.each do |model|

        model_string_field = model.to_s.tableize.singularize
        model_string_table = model.to_s.tableize

        # fields
        model.fastapi_fields_sub.each do |field|
          field_string = field.to_s
          field_list << [
            model_string_table,
            '.',
            field_string,
            ' as ',
            model_string_field,
            '__',
            field_string
          ].join('')
        end

        # joins
        joins << [
          'LEFT JOIN',
            model_string_table,
          'ON',
            model_string_table + '.id',
            '=',
            self_string_table + '.' + model_string_field + '_id'
        ].join(' ')

      end

      # Many fields (Many to 1)
      has_many.each do |model|

        model_string = model.to_s.tableize.singularize
        model_string_table = model.to_s.tableize
        model_symbol = model_string_table.to_sym

        model_fields = []

        model.fastapi_fields_sub.each do |field|
          field_string = field.to_s
          model_fields << [
            '__' + model_string_table + '.' + field_string,
            # 'as',
            # field_string
          ].join(' ')
        end

        has_many_filters = ''
        has_many_order = ''
        if filters[:has_many].has_key? model_symbol
          has_many_filters = 'AND ' + filters[:has_many][model_symbol].join(' AND ')
          if not filters[:has_many_order][model_symbol].nil?
            has_many_order = 'ORDER BY ' + filters[:has_many_order][model_symbol]
          end
        end

        field_list << [
          'ARRAY_TO_STRING(ARRAY(',
            'SELECT',
              'ROW(',
              model_fields.join(', '),
              ')',
            'FROM',
              model_string_table,
              'as',
              '__' + model_string_table,
            'WHERE',
              '__' + model_string_table + '.' + self_string + '_id IS NOT NULL',
              'AND __' + model_string_table + '.' + self_string + '_id',
              '=',
              self_string_table + '.id',
              has_many_filters,
              has_many_order,
          '), \',\')',
          'as',
          '__many__' + model_string_table
        ].join(' ')

      end

      filter_string = (filters[:main].size > 0 ? ('WHERE ' + filters[:main].join(' AND ')) : '')
      order_string = (filters[:main_order].nil? ? '' : 'ORDER BY ' + filters[:main_order])

      {
        query: [
          'SELECT',
            field_list.join(', '),
          'FROM',
            self_string_table,
          joins.join(' '),
          filter_string,
          order_string,
          'LIMIT',
            count.to_s,
          'OFFSET',
            offset.to_s,
        ].join(' '),
        count_query: [
          'SELECT COUNT(id) FROM',
            self_string_table,
          filter_string
        ].join(' '),
        models: model_lookup
      }

    end

end
