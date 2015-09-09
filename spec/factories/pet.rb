FactoryGirl.define do
  factory :pet do
    sequence(:name) { |n| "Example Pet #{n}" }
    color 'black'

    factory :red_pet do
      color 'red'
      nicknames %w(Ginger)
      favorite_dishes { [create(:margarita_pizza)] }
    end

    factory :brown_pet do
      color 'brown'
      nicknames %w(Acorn Meatloaf Mocha)
      favorite_dishes { [create(:cheeseburger), create(:burrito)] }
    end
  end
end
