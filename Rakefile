require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new

task default: :spec
task test: :spec

desc 'Open an irb session with library loaded and test schema loaded'
namespace :spec do
  task :console do
    load_gems_for_irb

    puts 'FastAPI console:'
    ARGV.clear
    IRB.start

    ActiveRecord::Tasks::DatabaseTasks.drop($db)
  end

  def load_gems_for_irb
    gems = %w(irb rspec factory_girl fastapi) << rake_root.join('spec', 'helpers', 'activerecord_helper')
    gems.each { |g| require g }
  end

  def rake_root
    path = File.expand_path(File.dirname(__FILE__))
    Pathname.new(path)
  end
end
