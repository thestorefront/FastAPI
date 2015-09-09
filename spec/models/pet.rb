class Pet < ActiveRecord::Base
  belongs_to :owner, class_name: 'Person'

  self.primary_key = :peoples_pets_id
  self.table_name = :peoples_pets

  fastapi_standard_interface        [:peoples_pets_id, :name, :color, :owner, :nicknames, :favorite_dishes]
  fastapi_standard_interface_nested [:peoples_pets_id, :name, :color, :nicknames, :favorite_dishes]
end
