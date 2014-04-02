
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

dirs = [ '.', 'lib' ]

RSpec::Core::RakeTask.new( :spec ) do |t|
  t.fail_on_error = true
end

Rubocop::RakeTask.new( :rubocop )

FlayTask.new( :flay ) do |flay|
  flay.dirs = dirs
end

FlogTask.new( :flog ) do |flog|
  flog.dirs = dirs
end

RDoc::TagsTask.new do |t|
  t.tag_style = 'vim'  # default
end

task quality: [ :flog, :flay, :rubocop ]

task test: :spec

task default: :test

# Last thing, invoke the tags task EVERY time we run this Rakefile.
# Rake::Task[ 'tags' ].invoke
