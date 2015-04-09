FactoryGirl.define do
  factory :dish do
    sequence(:name) { |n| "Example Dish #{n}" }

    factory :margarita_pizza do
      name 'margarita pizza'
      ingredients ['dough', 'marinara', 'mozarella', 'basil']
    end

    factory :cheeseburger do
      name 'cheeseburger'
      ingredients ['wheat bun', 'ground beef', 'american cheese', 'pickle', 'lettuce', 'onion', 'ketchup']
    end

    factory :burrito do
      name 'burrito'
      ingredients ['flour tortilla', 'shredded chicken', 'queso fresco', 'black beans', 'avocado']
    end
  end
end
