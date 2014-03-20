
require 'spec_helper'
require 'config/baseconfig'

require 'Tempfile'

module Dist

  describe "Base Configuration" do

    before( :all ) do

      @temp_files = Hash.new

      junk_attributes = Hash.new
      junk_attributes[ 'non_required_key' ] = 'non required value'

      @all_attributes = Hash.new
      @all_attributes[ 'name'       ] = 'Runner'
      @all_attributes[ 'redis_host' ] = 'localhost'
      @all_attributes[ 'redis_port' ] = 6379
      @all_attributes[ 'redis_pass' ] = 'slenderman'
      @all_attributes[ 'log_dir'    ] = './'
      @all_attributes[ 'debug'      ] = false

      @all_attributes.merge! junk_attributes

      @temp_files[ 'all' ] = ConfigHelpers.createTempConfig( 'all', @all_attributes )

      @all_attributes.each_key do |curr_key|

        curr_partial_attributes = @all_attributes.dup
        curr_partial_attributes.delete( curr_key )

        @temp_files[ curr_key ] = ConfigHelpers.createTempConfig( curr_key, curr_partial_attributes )

      end

      @temp_files[ 'empty' ] = ConfigHelpers.createTempConfig( 'empty', junk_attributes )

      debug_true = @all_attributes.dup
      debug_true[ 'debug' ] = true

      @temp_files[ 'debug_true' ] = ConfigHelpers.createTempConfig( 'debug_true', debug_true )
    end

    after( :all ) do
      ConfigHelpers.cleanupTempConfigList( @temp_files.values )
    end

    it "should instaniate without error when all required attributes are provided." do

      conf = BaseConfig.new( @temp_files[ 'all' ].path )

      @all_attributes.each_pair do |k,v|
        conf[ k ].should == v
      end

    end

    it "should raise an exception when all of the required attributes are missing." do

      expect { BaseConfig.new( @temp_files[ 'empty' ].path ) }.to raise_error( /Key (\S+) missing./ )

    end

    it "should raise an exception when any of the required attributes are missing." do

      required_attributes = @temp_files.keys - [ 'all', 'empty', 'non_required_key', 'debug_true' ]

      required_attributes.each do |curr_attribute|
        expect { BaseConfig.new( @temp_files[ curr_attribute ].path ) }.to raise_error( /Key #{ curr_attribute } missing./ )
      end

    end

    describe "affects $DEBUG" do

      describe "should not affect the value of $DEBUG when 'debug' attribute is false" do

        it "should leave $DEBUG=true alone." do

          expect {
            DebugHelpers.presetDebugStateAndValidateResult( true, true ) do
              BaseConfig.new( @temp_files[ 'all' ].path )
            end
          }.to be_true

        end

        it "should leave $DEBUG=false alone." do
          expect {
            DebugHelpers.presetDebugStateAndValidateResult( false, false ) do
              BaseConfig.new( @temp_files[ 'all' ].path )
            end
          }.to be_true

        end

      end

      describe "should affect the value of $DEBUG when 'debug' attribute is true" do

        it "should ensure that $DEBUG stays set when previously true." do

          expect {
            DebugHelpers.presetDebugStateAndValidateResult( true, true ) do
              BaseConfig.new( @temp_files[ 'debug_true' ].path )
            end
          }.to be_true

        end

        it "should ensure that $DEBUG gets set when previously false." do

          expect {
            DebugHelpers.presetDebugStateAndValidateResult( false, true ) do
              BaseConfig.new( @temp_files[ 'debug_true' ].path )
            end
          }.to be_true

        end

      end


    end

  end

end
