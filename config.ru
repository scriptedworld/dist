
require 'sinatra'

set :env, :production
disable :run

require './data.rb'

# NOTE: We aren't configuring our application here because the redis connections will get trashed when Unicorn forks.
#       Review unicorn.conf after_fork for our DataService setup details.

run Sinatra::Application

