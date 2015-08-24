module ModelHelper
  def self.response(clazz, filters = {}, options = {})
    api = clazz.fastapi

    if options.key?(:whitelist)
      api.whitelist(options[:whitelist])
    end

    meta = options.key?(:meta) ? options[:meta] : {}

    results = options[:safe] ? api.safe_filter(filters, meta) : api.filter(filters, meta)

    Oj.load(results.response)
  end

  def self.fetch(clazz, id)
    results = clazz.fastapi.fetch(id)
    Oj.load(results.response)
  end

  def self.spoof!(clazz, data, options = {})
    api = clazz.fastapi

    if options.key?(:whitelist)
      api.whitelist(options[:whitelist])
    end

    meta = options.key?(:meta) ? options[:meta] : {}

    results = api.spoof!(data, meta)

    Oj.load(results)
  end
end
