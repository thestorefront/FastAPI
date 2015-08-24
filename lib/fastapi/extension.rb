module Extension
  extend ActiveSupport::Concern

  module ClassMethods
    # Used to set the standard interface for the top level of a fastapi response
    #
    # @param fields [Array] a list of fields in the form of symbols
    # @return [Array] the same array of fields
    def fastapi_standard_interface(fields)
      @fastapi_fields = fields
    end

    # Used to set the standard interface for the second level of a fastapi response (nested)
    #
    # @param fields [Array] a list of fields in the form of symbols
    # @return [Array] the same array of fields
    def fastapi_standard_interface_nested(fields)
      @fastapi_fields_sub = fields
    end

    # Set safe fields for FastAPIInstance.safe_filter
    # These are the fields that can be actively filtered by
    #
    # @param fields [Array] a list of fields in the form of symbols
    # @return [Array] the same array of fields
    def fastapi_safe_fields(fields)
      @fastapi_filters_whitelist = fields
    end

    # Used to set any default filters for the top level fastapi response
    #
    # @param filters [Hash] a hash containing the intended filters
    # @return [Hash] the same filters hash
    def fastapi_default_filters(filters)
      @fastapi_filters = filters
    end

    # Define custom ORDER BY strings for specific keys
    #
    # @param keys [Hash] a hash containing the keys: strings for order filters
    # @return [Hash] the same keys hash
    def fastapi_define_order(keys)
      @fastapi_custom_order = keys
    end

    def fastapi_custom_order
      @fastapi_custom_order || {}
    end

    def fastapi_fields
      @fastapi_fields || [primary_key.to_sym]
    end

    def fastapi_fields_sub
      @fastapi_fields_sub || [primary_key.to_sym]
    end

    def fastapi_filters_whitelist
      @fastapi_filters_whitelist || @fastapi_fields || [primary_key.to_sym]
    end

    def fastapi_filters
      @fastapi_filters || {}
    end

    def fastapi
      FastAPI::Wrapper.new(self)
    end
  end
end

ActiveRecord::Base.send(:include, Extension)
