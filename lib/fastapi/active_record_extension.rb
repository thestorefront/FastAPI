require 'active_record'

module FastAPIExtension

  extend ActiveSupport::Concern

  module ClassMethods

    def fastapi_standard_interface(fields)
      @fastapi_fields = fields
    end

    def fastapi_standard_interface_nested(fields)
      @fastapi_fields_sub = fields
    end

    def fastapi_default_filters(filters)
      @fastapi_filters = filters
    end

    def fastapi_fields
      @fastapi_fields or [:id]
    end

    def fastapi_fields_sub
      @fastapi_fields_sub or [:id]
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
