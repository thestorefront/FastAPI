module FastAPI
  module Conversions

    @@boolean_hash = { 't' => true, 'f' => false }

    def self.convert_type(val, type, field = nil)
      if val && array?(field)
        Oj.load(val).map { |inner_value| convert_value(inner_value, type) }
      else
        convert_value(val, type)
      end
    end

    private

    def self.array?(field)
      field && field.respond_to?('array') && field.array
    end

    def self.convert_value(val, type)
      if val
        case type
        when :integer
          val.to_i
        when :float
          val.to_f
        when :boolean
          @@boolean_hash[val]
        else
          val
        end
      end
    end
  end
end
