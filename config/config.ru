
this_dir = File.dirname( __FILE__ )
$LOAD_PATH << this_dir unless $LOAD_PATH.include? this_dir
lib_dir = File.join( this_dir, 'lib' )
$LOAD_PATH << lib_dir unless $LOAD_PATH.include? lib_dir

require 'sinatra'

set :env, :production
disable :run

require 'dist/data/server'

# NOTE: We aren't configuring our application here because the redis connections will get trashed when Unicorn forks.
#       Review unicorn.conf after_fork for our DataService setup details.

run Dist::DataServer

