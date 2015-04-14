FactoryGirl.define do
  factory :person do
    sequence(:name)    { |n| "Example Person #{n}" }
    gender             { %w(Male Female).sample }
    sequence(:age, 20)

    factory :example_person do
      name 'Example Person'
    end

    factory :person_with_buckets do
      name 'Person with Buckets'

      transient do
        bucket_count 5
      end

      after(:create) do |person, evaluator|
        create_list(:bucket, evaluator.bucket_count, person: person)
      end
    end

    factory :person_with_incomplete_bucket do
      name 'Person with Incomplete Bucket'

      transient do
        bucket_count 1
      end

      after(:create) do |person, evaluator|
        create_list(:bucket, evaluator.bucket_count, person: person,
                    color: nil, material: 'plastic')
      end
    end

    factory :person_with_buckets_with_quotes_and_spaces do
      name 'Person with Buckets with quotes and spaces'

      transient do
        bucket_count 1
      end

      after(:create) do |person, evaluator|
        create_list(:bucket, evaluator.bucket_count, person: person,
                   color: '"abc def"', material: 'paper')
        create_list(:bucket, evaluator.bucket_count, person: person,
                   color: '" abcdef"', material: 'paper')
        create_list(:bucket, evaluator.bucket_count, person: person,
                   color: '"abcdef "', material: 'paper')
      end
    end
  end
end
