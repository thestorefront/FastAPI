# set the rails environment variable for testing
ENV['RAILS_ENV'] = 'test'

# load the database configuration

path = File.expand_path(File.dirname(__FILE__))
root = Pathname.new(path).join('..')
$db  = YAML.load_file(root.join('db', 'database.yml'))['test']

# create the database and connect
ActiveRecord::Tasks::DatabaseTasks.create($db)
ActiveRecord::Base.establish_connection($db)

# load the schema
require root.join('db', 'schema.rb')

# load all the models
Dir[root.join('models', '*.rb')].each { |m| require m }

# load the factories
Dir[root.join('factories', '*.rb')].each { |f| require f }
