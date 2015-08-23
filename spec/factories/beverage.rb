FactoryGirl.define do
  factory :beverage do
    sequence(:name) { |n| "Example Beverage #{n}" }

    factory :water do
      name 'water'
      flavors %w(water)
    end

    factory :coke do
      name 'Coca-Cola'
      flavors %w(sweet vanilla cinnamon orange lime lemon nutmeg)
    end

    factory :beer do
      name 'Hell Or High Watermelon'
      flavors %w(sweet watermelon wheat yeast)
    end
  end
end
