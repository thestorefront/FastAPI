class Beverage < ActiveRecord::Base
  belongs_to :dish

  fastapi_standard_interface [:id, :name, :flavors, :dish]
  fastapi_standard_interface_nested [:id, :name, :flavors]
end
