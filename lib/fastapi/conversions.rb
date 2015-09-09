module FastAPI
  module Conversions

    @@boolean_hash = { 't' => true, 'f' => false }

    def self.convert_type(val, type, field = nil)
      if val.present? && array?(field)
        convert_array(Oj.load(val), type)
      elsif val.respond_to?(:map)
        convert_array(val, type)
      else
        convert_value(val, type)
      end
    end

    private

    def self.array?(field)
      field && field.respond_to?('array') && field.array
    end

    def self.convert_array(array, type)
      array.map { |inner_value| convert_value(inner_value, type) }
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
