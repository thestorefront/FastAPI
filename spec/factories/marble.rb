FactoryGirl.define do
  factory :marble do
    color  { %w(red green blue black white orange).sample }
    radius { (1..10).to_a.sample }

    factory :blue_marble do
      color 'blue'
    end

    factory :red_marble do
      color 'red'
    end
  end
end
