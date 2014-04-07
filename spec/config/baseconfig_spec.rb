
require 'spec_helper'
require 'dist/config/baseconfig'

module Dist

  describe 'Base Configuration' do

    include Helpers
    include ConfigHelpers
    include DebugHelpers

    before( :all ) do

      @attribute_hashes = Hash.new

      junk_attributes = Hash.new
      junk_attributes[ 'non_required_key' ] = 'non required value'

      @all_attributes = Hash.new
      @all_attributes[ 'name'       ] = 'Runner'
      @all_attributes[ 'redis_host' ] = 'localhost'
      @all_attributes[ 'redis_port' ] = 6379
      @all_attributes[ 'redis_pass' ] = 'slenderman'
      @all_attributes[ 'debug'      ] = false

      @all_attributes.merge! junk_attributes

      @attribute_hashes[ :all ] = @all_attributes

      @all_attributes.each_key do |curr_key|

        curr_partial_attributes = @all_attributes.dup
        curr_partial_attributes.delete( curr_key )

        @attribute_hashes[ curr_key ] = curr_partial_attributes

      end

      debug_true = @all_attributes.dup
      debug_true[ 'debug' ] = true
      @attribute_hashes[ :debug_true ] = debug_true

      debug_false = @all_attributes.dup
      debug_false[ 'debug' ] = false
      @attribute_hashes[ :debug_false ] = debug_false

    end

    it 'should instaniate without error when all required attributes are provided.' do

      with_config( @all_attributes, BaseConfig, disable_base_attributes: true ) do |conf|
        @all_attributes.each_pair do |k, v|
          expect( conf[ k ] ).to eq( v )
        end
      end

    end

    it 'should raise an exception when all of the required attributes are missing.' do

      expect_new_config_to_raise_error( {}, BaseConfig, /Key (\S+) missing./, disable_base_attributes: true )

    end

    it 'should raise an exception when any of the required attributes are missing.' do

      required_attributes = @attribute_hashes.keys.reject! { |item| item.instance_of?( Symbol ) }

      required_attributes -= [ 'non_required_key' ]

      required_attributes.each do |curr_attribute|
        expect_new_config_to_raise_error( @attribute_hashes[ curr_attribute ], BaseConfig, /Key #{ curr_attribute } missing./, disable_base_attributes: true )
      end

    end

    it 'affects $DEBUG when true.' do
      test_debug_state( true, true, @attribute_hashes[ :debug_true ] )
      test_debug_state( false, true, @attribute_hashes[ :debug_true ] )
    end

    it 'does not affect $DEBUG when false.' do
      # Calls with debug provided and == false
      test_debug_state( true, true, @attribute_hashes[ :debug_false ] )
      test_debug_state( false, false, @attribute_hashes[ :debug_false ] )
    end

  end

end
