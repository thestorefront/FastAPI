FactoryGirl.define do
  factory :bucket do
    color    { %w(red green blue black white orange).sample }
    material { %w(wood plastic paper concrete).sample }
    used     false

    factory :used_bucket do
      used true
    end

    factory :red_plastic_bucket do
      color    'red'
      material 'plastic'
    end

    factory :blue_paper_bucket do
      color    'blue'
      material 'paper'
    end

    factory :bucket_with_marbles do
      transient do
        marble_count 10
        marble_radius 1
      end

      after(:create) do |bucket, evaluator|
        create_list(:marble, evaluator.marble_count, bucket: bucket,
                    radius: evaluator.marble_radius)
      end
    end

    factory :bucket_with_incomplete_marble do
      transient do
        marble_count 1
      end

      after(:create) do |bucket, evaluator|
        create_list(:marble, evaluator.marble_count, bucket: bucket,
                   color: nil, radius: 5)
      end
    end
  end
end
