module FastAPI
  class Comparison
    attr_reader :sql
    alias_method :to_s, :sql

    @@scalar_input = {
      is:  '__FIELD__ = __VALUE__',
      not: '__FIELD__ <> __VALUE__',
      gt:  '__FIELD__ > __VALUE__',
      gte: '__FIELD__ >= __VALUE__',
      lt:  '__FIELD__ < __VALUE__',
      lte: '__FIELD__ <= __VALUE__',
      like:   '__FIELD__ LIKE \'%\' || __VALUE__ || \'%\'',
      ilike:  '__FIELD__ ILIKE \'%\' || __VALUE__ || \'%\'',
      not_like:   'NOT (__FIELD__ LIKE \'%\' || __VALUE__ || \'%\')',
      not_ilike:  'NOT (__FIELD__ ILIKE \'%\' || __VALUE__ || \'%\')',
      null:    '__FIELD__ IS NULL',
      not_null:   '__FIELD__ IS NOT NULL'
    }.with_indifferent_access

    @@multi_input = {
      in: '__FIELD__ IN (__VALUES__)',
      not_in: '__FIELD__ NOT IN (__VALUES__)',
      subset: '__FIELD__ <@ ARRAY[__VALUES__]::__TYPE__[]',
      not_subset: 'NOT __FIELD__ <@ ARRAY[__VALUES__]::__TYPE__[]',
      contains: '__FIELD__ @> ARRAY[__VALUES__]::__TYPE__[]',
      not_contains: 'NOT __FIELD__ @> ARRAY[__VALUES__]::__TYPE__[]',
      intersects:     '__FIELD__ && ARRAY[__VALUES__]::__TYPE__[]',
      not_intersects: 'NOT __FIELD__ && ARRAY[__VALUES__]::__TYPE__[]'
    }.with_indifferent_access

    @@booleans = {
      t: true,
      true: true,
      f: false,
      false: false
    }.with_indifferent_access

    @@types = Hash.new('text').merge(
      boolean: 'boolean',
      integer: 'integer',
      float:   'float',
      string:  'varchar'
    ).with_indifferent_access

    def self.valid_comparator?(comparator)
      @@scalar_input.key?(comparator) || @@multi_input.key?(comparator)
    end

    def self.invalid_comparator?(comparator)
      !valid_comparator?(comparator)
    end

    def initialize(comparator, value, field, type)
      key = prepare_comparator(comparator, value)
      val = prepare_value(value, type)
      if clause = @@scalar_input[key]
        @sql = scalar_sql(clause, field, val)
      elsif clause = @@multi_input[key]
        @sql = multi_sql(clause, val, field, type)
      else
        raise ArgumentError.new("Invalid comparator: #{key}")
      end
    end

    private

    def prepare_comparator(comparator, value)
      if value.nil? && comparator == 'is'
        :null
      else
        comparator
      end
    end

    def prepare_value(value, type)
      type == :boolean && !!value != value ? @@booleans[value] : value
    end

    def scalar_sql(clause, field, value)
      clause.sub('__FIELD__', field).sub('__VALUE__', ActiveRecord::Base.connection.quote(value))
    end

    def multi_sql(clause, value, field, type)
      values = [*value].map { |v| ActiveRecord::Base.connection.quote(v) }.join(',')
      [clause.sub('__FIELD__', field).sub('__VALUES__', values).sub('__TYPE__', @@types[type])].compact.join
    end
  end
end
