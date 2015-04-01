module ModelHelper
  def self.get_response(clazz, filter = {})
    results = clazz.fastapi.filter(filter)
    JSON.parse(results.response)
  end
end
