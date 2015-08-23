FactoryGirl.define do
  factory :dish do
    sequence(:name) { |n| "Example Dish #{n}" }

    factory :margarita_pizza do
      name 'margarita pizza'
      ingredients %w(dough marinara mozarella basil)
    end

    factory :cheeseburger do
      name 'cheeseburger'
      ingredients %w(wheat bun ground beef american\ cheese pickle lettuce onion ketchup)

      factory :cheeseburger_with_beer do
        association :beverage, factory: :beer
      end
    end

    factory :burrito do
      name 'burrito'
      ingredients %w(flour\ tortilla shredded\ chicken queso\ fresco black\ beans avocado)

      factory :burrito_with_coke do
        association :beverage, factory: :coke
      end
    end
  end
end
