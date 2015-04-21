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
      contains:   "__FIELD__ LIKE '%' || __VALUE__ || '%'",
      contains_a: '__VALUE_ = ANY(__FIELD__)',
      icontains:  "__FIELD__ ILIKE '%' || __VALUE__ || '%'",
      is_null:    '__FIELD__ IS NULL',
      not_null:   '__FIELD__ IS NOT NULL'
    }.with_indifferent_access

    @@multi_input = {
      in:   '__FIELD__ IN (__VALUES__)',
      in_a: '__FIELD__ @> ARRAY[__VALUES__]',
      not_in:   '__FIELD__ NOT IN (__VALUES__)',
      not_in_a: 'NOT __FIELD__ @> ARRAY[__VALUES__]',
      intersects_a:     '__FIELD__ && ARRAY[__VALUES__]',
      not_intersects_a: 'NOT __FIELD__ && ARRAY[__VALUES__]'
    }.with_indifferent_access

    @@booleans = {
      t: true,
      true: true,
      f: false,
      false: false
    }.with_indifferent_access

    @@types = Hash.new('::text').merge({
      boolean: '::boolean',
      integer: '::integer',
      float:   '::float',
      string:  '::varchar[]'
    }).with_indifferent_access

    def self.valid_comparator?(comparator)
      [comparator, "#{comparator}_a"].any? do |c|
        @@scalar_input.key?(c) || @@multi_input.key?(c)
      end
    end

    def self.invalid_comparator?(comparator)
      !valid_comparator?(comparator)
    end

    def initialize(comparator, value, field, type, is_array)
      key = prepare_comparator(comparator, value, is_array)
      val = prepare_value(value, type)
      if clause = @@scalar_input[key]
        @sql = scalar_sql(clause, field, val)
      elsif clause = @@multi_input[key]
        @sql = multi_sql(clause, val, field, type, is_array)
      else
        raise ArgumentError.new("Invalid comparator: #{key}")
      end
    end

    private
    def prepare_comparator(comparator, value, is_array)
      if value.nil?
        comparator == 'not_null' ? comparator : :is_null
      else
        is_array ? "#{comparator}_a" : comparator
      end
    end

    def prepare_value(value, type)
      type == :boolean && !!value != value ? @@booleans[value] : value
    end

    def scalar_sql(clause, field, value)
      clause.sub('__FIELD__', field).sub('__VALUE__', ActiveRecord::Base.connection.quote(value))
    end

    def multi_sql(clause, value, field, type, is_array)
      values = value.map { |v| ActiveRecord::Base.connection.quote(v) }.join(',')
      [clause.sub('__FIELD__', field).sub('__VALUES__', values), (is_array ? @@types[type] : nil)].compact.join
    end
  end
end
