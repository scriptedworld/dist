
require 'tempfile'
require 'yaml'

require 'dist/helpers'

module Dist

  module ConfigHelpers

    include Helpers

    def getBaseConfigHash()

      {
        'name'       => 'config name',
        'redis_host' => 'localhost',
        'redis_port' => 6379,
        'redis_pass' => 'slenderman',
        'log_dir'    => './',
        'debug'      => false
      }

    end

    def createTempConfigFile( name, from_hash = {}, additional_params = {} )

      temp_file = Tempfile.new( "#{ name }.yaml" )

      attributes = nil

      if( from_hash.instance_of?( Hash ) )
        attributes = Hash.new
        attributes.merge!( getBaseConfigHash() ) if additional_params[ :include_base_attributes ]
        attributes.merge!( from_hash )
      else
        # Handle when the test wants to use something other than a Hash in the temp file.
        attributes = from_hash
      end

      temp_file.write( attributes.to_yaml )
      temp_file.close

      temp_file

    end

    def cleanupTempConfigFile( temp_file )
      temp_file.unlink
    end

    def cleanupTempConfigFiles( temp_file_list = [] )
      temp_file_list.each do |curr_temp_file|
        curr_temp_file.unlink
      end
    end

    def withTempFileFromAttributes( attributes, additional_params = {} )

      temp_file = createTempConfigFile( 'temp', attributes, additional_params )

      begin
        yield temp_file
      ensure
        cleanupTempConfigFile( temp_file )
      end

    end

    def withConfig( attributes, config_class, additional_params = {}, &block )
      withTempFileFromAttributes( attributes, additional_params ) do |temp_file|
        conf = config_class.new( temp_file.path )
        yield conf
      end
    end

    def expectNewConfigToRaiseError( attributes, config_class, expected_error_message, additional_params = {} )

      withTempFileFromAttributes( attributes, additional_params ) do |temp_file|

        expect {
          config_class.new( temp_file.path )
        }.to raise_error( expected_error_message )

      end

    end

    def kindOfBaseConfig( attributes, config_class, additional_params = {} )
      withConfig( attributes, config_class, additional_params ) do |conf|
        expect( conf ).to be_a_kind_of( BaseConfig )
      end
    end

  end

end
