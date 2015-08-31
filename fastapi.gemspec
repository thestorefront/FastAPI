Gem::Specification.new do |s|

  s.name          = 'fastapi'
  s.version       = '0.2.1'
  s.summary       = 'Easily create robust, standardized API endpoints using lightning-fast database queries'
  s.description   = 'Easily create robust, standardized API endpoints using lightning-fast database queries'
  s.authors       = ['Keith Horwood', 'Trevor Strieber']
  s.email         = ['keithwhor@gmail.com', 'trevor@strieber.org']
  s.files         = Dir['lib/**/*']
  s.homepage      = 'https://github.com/thestorefront/FastAPI'
  s.license       = 'MIT'

  s.add_runtime_dependency 'activerecord', '>= 3.2.0'

  s.add_runtime_dependency 'oj', '>= 2.9.9'
  s.add_runtime_dependency 'pg', '>= 0.18.1'

  s.add_development_dependency 'rake', '~> 10.0'
  s.add_development_dependency 'bundler', '>= 1.3'

  s.add_development_dependency 'rspec', '~> 3.2.0'
  s.add_development_dependency 'factory_girl', '~> 4.0'
  s.add_development_dependency 'database_cleaner', '~> 1.4.1'

  s.required_ruby_version = '>= 1.9.3'
end
