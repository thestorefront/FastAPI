class Person < ActiveRecord::Base
  has_many :buckets
  has_many :dishes

  fastapi_standard_interface        [:id, :name, :gender, :age, :buckets, :dishes]
  fastapi_standard_interface_nested [:id, :name, :gender, :age]
end
