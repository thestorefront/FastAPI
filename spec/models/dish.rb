class Dish < ActiveRecord::Base
  has_one :beverage
  belongs_to :person

  fastapi_standard_interface [:id, :name, :ingredients, :beverage, :person]
  fastapi_standard_interface_nested [:id, :name, :ingredients]
end
