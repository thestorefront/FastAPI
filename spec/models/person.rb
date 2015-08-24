class Person < ActiveRecord::Base
  has_many :buckets
  has_many :dishes
  has_many :pets, foreign_key: :owner_id

  fastapi_standard_interface        [:id, :name, :gender, :age, :buckets, :dishes, :pets]
  fastapi_standard_interface_nested [:id, :name, :gender, :age]
end
