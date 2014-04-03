
require 'tempfile'
require 'yaml'

require 'dist/helpers'

module Dist

  module ConfigHelpers

    include Helpers

    def base_config_hash

      {
        'name'       => 'config name',
        'redis_host' => 'localhost',
        'redis_port' => 6379,
        'redis_pass' => 'slenderman',
        'log_dir'    => './',
        'debug'      => false
      }

    end

    def create_temp_config_file( name, from_hash = {}, additional_params = {} )

      temp_file = Tempfile.new( "#{ name }.yaml" )

      attributes = nil

      if from_hash.instance_of?( Hash )
        attributes = {}

        # The 'base' attributes mentioned here come from the attributes that are required by all configuration
        # classes derived from BaseConfig. Most config classes use these.
        attributes.merge!( base_config_hash ) unless additional_params[ :disable_base_attributes ]

        attributes.merge!( from_hash )
      else
        # Handle when the test wants to use something other than a Hash in the temp file.
        attributes = from_hash
      end

      temp_file.write( attributes.to_yaml )
      temp_file.close

      temp_file

    end

    def cleanup_temp_config_file( temp_file )
      temp_file.unlink
    end

    def cleanup_temp_config_files( temp_file_list = [] )
      temp_file_list.each do |curr_temp_file|
        curr_temp_file.unlink
      end
    end

    def with_temp_file_from_attributes( attributes, additional_params = {} )

      temp_file = create_temp_config_file( 'temp', attributes, additional_params )

      begin
        yield temp_file
      ensure
        cleanup_temp_config_file( temp_file )
      end

    end

    def with_config( attributes, config_class, additional_params = {}, &block )
      with_temp_file_from_attributes( attributes, additional_params ) do |temp_file|
        conf = config_class.new( temp_file.path )
        yield conf
      end
    end

    def expect_new_config_to_raise_error( attributes, config_class, expected_error_message, additional_params = {} )

      with_temp_file_from_attributes( attributes, additional_params ) do |temp_file|
        expect { config_class.new( temp_file.path ) }.to raise_error( expected_error_message )
      end

    end

    def expect_validate_to_raise_error( config_object, expected_error_message )
      expect { config_object.validate }.to raise_error( expected_error_message )
    end

    def kind_of_baseconfig( attributes, config_class, additional_params = {} )
      with_config( attributes, config_class, additional_params ) do |conf|
        expect( conf ).to be_a_kind_of( BaseConfig )
      end
    end

  end

end
