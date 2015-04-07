module ModelHelper
  def self.response(clazz, filter = {}, options = {})
    api = clazz.fastapi

    if options.key?(:whitelist)
      api.whitelist([*options[:whitelist]])
    end

    results = options[:safe] ? api.safe_filter(filter) : api.filter(filter)

    JSON.parse(results.response)
  end

  def self.fetch(clazz, id)
    results = clazz.fastapi.fetch(id)
    JSON.parse(results.response)
  end
end
