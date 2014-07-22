require 'active_record'

module FastAPIExtension

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
    #
    # @param fields [Array] a list of fields in the form of symbols
    # @return [Array] the same array of fields
    def fastapi_safe_fields(fields)
      @fastapi_fields_whitelist = fields
    end

    # Used to set any default filters for the top level fastapi response
    #
    # @param filters [Hash] a hash containing the intended filters
    # @return [Hash] the same filters hash
    def fastapi_default_filters(filters)
      @fastapi_filters = filters
    end

    def fastapi_fields
      @fastapi_fields or [:id]
    end

    def fastapi_fields_sub
      @fastapi_fields_sub or [:id]
    end

    def fastapi_fields_whitelist
      @fastapi_fields_whitelist or @fastapi_fields or [:id]
    end

    def fastapi_filters
      @fastapi_filters or {}
    end

    def fastapi
      FastAPI.new(self)
    end

  end

end

ActiveRecord::Base.send(:include, FastAPIExtension)
