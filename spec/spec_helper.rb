
this_dir = File.dirname( __FILE__ )
$LOAD_PATH << this_dir unless $LOAD_PATH.include? this_dir
lib_dir = File.join( this_dir, '..', 'lib' )
$LOAD_PATH << lib_dir unless $LOAD_PATH.include? lib_dir

require 'simplecov'
SimpleCov.start do
  add_filter "/spec/"
end

require 'rspec/expectations'

require 'config_helpers'
require 'debug_helpers'
require 'config/baseconfig'

