require 'yaml'
require 'active_record'
require 'fastapi'
require 'factory_girl'
require 'database_cleaner'

require 'helpers/activerecord_helper'
require 'helpers/model_helper'

require 'shared/fastapi_model'
require 'shared/fastapi_meta'
require 'shared/fastapi_data'

RSpec.configure do |config|
  config.include FactoryGirl::Syntax::Methods

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  config.after(:suite) do
    ActiveRecord::Tasks::DatabaseTasks.drop($db)
  end
end
