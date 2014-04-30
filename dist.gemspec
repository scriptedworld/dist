require 'rake'

Gem::Specification.new do |s|

  s.name         = 'dist'
  s.description  = 'A job scheduling/execution/monitoring framework used in load & interaction testing.'
  s.version      = '2.0.1'
  s.summary      = 'Distributed job execution & management system.'
  s.date         = '2014-03-26'
  s.authors      = 'Jeff Wood'
  s.email        = 'j@a1ph4g33k.com'
  s.homepage     = 'http://github.com/a1ph4g33k/dist'
  s.license      = 'MIT'

  s.require_path = 'lib'

  s.bindir       = 'bin'
  s.executables << 'dist-manager'
  s.executables << 'dist-reporter'
  s.executables << 'dist-runner'
  s.executables << 'dist-worker'

  s.files        = FileList[ 'lib/**/*.rb',
                             'bin/*',
                             'config/*'
                           ]

  # s.add_runtime_dependency     'sinatra',       '>= 1.4.4'
  # s.add_runtime_dependency     'gruff',         '>= 0.5.1'

  s.add_runtime_dependency 'json',          '>= 1.8.0', '< 2'
  s.add_runtime_dependency 'awesome_print', '~> 1.1', '>= 1.1.0'
  s.add_runtime_dependency 'redis',         '~> 3.0', '>= 3.0.4'
  s.add_runtime_dependency 'hiredis',       '~> 0.4', '>= 0.4.5'
  s.add_runtime_dependency 'pry',           '~> 0.9', '>= 0.9.12.2'

end
