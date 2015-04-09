class Dish < ActiveRecord::Base

  fastapi_standard_interface [:id, :name, :ingredients]
end
