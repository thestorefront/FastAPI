require 'active_record'

module FastAPIExtension

  extend ActiveSupport::Concern

  module ClassMethods

    # Set the standard interface for the top level of a FastAPI response.
    #
    # @param fields [Array<Symbol>, :all] a list of fields or <tt>:all</tt> to include all fields
    # @param options [Hash] optional configuration when using <tt>:all</tt>, ignored otherwise
    # @option options [Array<Symbol>] :except ([]) a list of fields to exclude
    # @option options [Boolean] :timestamps (false) include <tt>created_at</tt> and <tt>updated_at</tt> fields
    # @option options [Boolean] :foreign_keys (false) include fields used to associate models
    # @option options [Boolean] :associations (true) include nested objects
    # @return [Array<Symbol>] the list of fields included in the FastAPI response
    def fastapi_standard_interface(fields, options = {})
      if fields == :all
        @fastapi_fields = attributes(options)
      else
        @fastapi_fields = fields
      end
    end

    # Set the standard interface for the second level of a FastAPI response (nested).
    #
    # @param fields [Array<Symbol>, :all] a list of fields or <tt>:all</tt> to include all fields
    # @param options [Hash] optional configuration when using <tt>:all</tt>, ignored otherwise
    # @option options [Array<Symbol>] :except ([]) a list of fields to exclude
    # @option options [Boolean] :timestamps (false) include <tt>created_at</tt> and <tt>updated_at</tt> fields
    # @option options [Boolean] :foreign_keys (false) include fields used to associate models
    # @return [Array<Symbol>] the list of fields included in the FastAPI response
    def fastapi_standard_interface_nested(fields, options = {})
      if fields == :all
        @fastapi_fields_sub = attributes(options.merge({ associations: false }))
      else
        @fastapi_fields_sub = fields
      end
    end

    # Set safe fields for FastAPIInstance.safe_filter.
    #
    # @param fields [Array<Symbol>] a list of fields
    # @return [Array<Symbol>] the same array of fields
    def fastapi_safe_fields(fields)
      @fastapi_fields_whitelist = fields
    end

    # Set any default filters for the top level FastAPI response.
    #
    # @param filters [Hash] a hash containing the intended filters
    # @return [Hash] the same filters hash
    def fastapi_default_filters(filters)
      @fastapi_filters = filters
    end

    # Define custom ORDER BY strings for specific keys.
    #
    # @param keys [Hash] a hash containing the keys: strings for order filters
    # @return [Hash] the same keys hash
    def fastapi_define_order(keys)
      @fastapi_custom_order = keys
    end

    def fastapi_custom_order
      @fastapi_custom_order or {}
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

    private
    def default_options
      @@opts ||= { except: [], timestamps: false, foreign_keys: false, associations: true }
    end

    def attributes(options)
      options.reverse_merge!(default_options)
      names = self.attribute_names.map(&:to_sym)

      names -= foreign_keys unless options[:foreign_keys]
      names -= timestamps   unless options[:timestamps]
      names += associations if     options[:associations]

      names -= [*options[:except]]
    end

    def associations
      self.reflections.keys.map(&:to_sym)
    end

    def foreign_keys
      self.reflections.map { |k, v| v.foreign_key.to_sym }
    end

    def timestamps
      [:created_at, :created_on, :updated_at, :updated_on]
    end
  end
end

ActiveRecord::Base.send(:include, FastAPIExtension)
