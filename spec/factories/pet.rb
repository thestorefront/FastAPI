FactoryGirl.define do
  factory :pet do
    sequence(:name) { |n| "Example Pet #{n}" }
    color 'black'

    factory :red_pet do
      color 'red'
    end

    factory :brown_pet do
      color 'brown'
    end
  end
end
