
require 'rake'
require 'rake/tasklib'

require 'flay'
require 'flay_task'

require 'flog'
require 'flog_task'

require 'rubocop'
require 'rubocop/rake_task'

require 'rspec'
require 'rspec/core/rake_task'

require 'rdoc/tags_task'

RSpec::Core::RakeTask.new( :spec ) do |t|
  t.fail_on_error = true
end

Rubocop::RakeTask.new( :rubocop ) do |rubocop|
  # nothing to do.
end

FlayTask.new( :flay ) do |flay|
  flay.dirs = [ '.', 'lib' ]
end

FlogTask.new( :flog ) do |flog|
  flog.dirs = [ '.', 'lib' ]
end

RDoc::TagsTask.new do |t|
  t.tag_style = 'vim'  # default
  # t.tags_dir  = '.'    # default
  # t.tags_file = 'tags'
end

task :quality   => [ :flog, :flay, :rubocop ]
# task :quality   => [ :flog, :flay ]
# task :quality => [ :flog, :flay                  ]
# task :test    => [ :spec, :quality               ]

task :test => :spec

task :default => :test

# Last thing, invoke the tags task EVERY time we run this Rakefile.
Rake::Task[ "tags" ].invoke

