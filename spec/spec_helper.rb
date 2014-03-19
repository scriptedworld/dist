
require 'simplecov'
SimpleCov.start do
  add_filter "/spec/"
end

require './lib/config/baseconfig.rb'

module ConfigHelpers

  def self.createTempConfig( name, from_hash = {} )

    temp_file = Tempfile.new( "#{ name }.yaml" )
    temp_file.write( from_hash.to_yaml )
    temp_file.close

    temp_file

  end

  def self.cleanupTempConfig( temp_file )
    temp_file.unlink
  end

  def self.cleanupTempConfigList( temp_file_list = [] )
    temp_file_list.each do |curr_temp_file|
      curr_temp_file.unlink
    end
  end

  def self.getBaseConfigHash()

    {
      'name'       => 'config name',
      'redis_host' => 'localhost',
      'redis_port' => 6379,
      'redis_pass' => 'slenderman',
      'log_dir'    => './',
      'debug'      => false
    }

  end

  def self.createAdvancedTempConfig( name, additional_params = {} )

    attributes = {}
    attributes.merge! getBaseConfigHash
    attributes.merge! additional_params

    createTempConfig( name, attributes )

  end

  def self.withAdvancedTempConfigBasedOnAttributes( attributes )

    temp_file = createAdvancedTempConfig( 'temp', attributes )

    yield temp_file

    cleanupTempConfig( temp_file )

  end

end

module DebugHelpers

  def self.presetDebugStateAndValidateResult( pre_debug_state, expected_debug_state, &block )

    old_state = $DEBUG
    $DEBUG = pre_debug_state

    yield

    result = ( $DEBUG == expected_debug_state )

    $DEBUG = old_state

    result

  end

end
