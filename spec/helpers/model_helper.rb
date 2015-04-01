module ModelHelper
  def self.response(clazz, filter = {})
    results = clazz.fastapi.filter(filter)
    JSON.parse(results.response)
  end

  def self.whitelisted_response(clazz, whitelist, filter = {})
    results = clazz.fastapi.whitelist([*whitelist]).filter(filter)
    JSON.parse(results.response)
  end
end
