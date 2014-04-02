require 'spec_helper'
require 'dist/config/workerconfig'

module Dist

  describe 'Worker Configuration Files' do

    include Helpers
    include ConfigHelpers

    before( :all ) do

      all_attributes_polling                            = Hash.new
      all_attributes_polling[ 'queue_method'          ] = 'polling'
      all_attributes_polling[ 'polling_timing'        ] = 'randomized'
      all_attributes_polling[ 'polling_delay_seconds' ] = 1.0
      all_attributes_polling[ 'polling_delay_stdev'   ] = 0.25

      all_attributes_signals                            = Hash.new
      all_attributes_signals[ 'queue_method'          ] = 'signals'

      @attribute_hashes = Hash.new
      @attribute_hashes[ :all_polling ] = all_attributes_polling
      @attribute_hashes[ :all_signals ] = all_attributes_signals

      @attribute_hashes[ :empty ] = Hash.new

    end

    it 'should be derived from BaseConfig' do
      kind_of_baseconfig( @attribute_hashes[ :all_polling ], WorkerConfig )
    end

    it 'requires a queue_method parameter' do
      expect_new_config_to_raise_error( @attribute_hashes[ :empty ], WorkerConfig, 'Key queue_method missing.' )
    end

    it 'should raise an exception if any value other than "polling" or "signals" is provided for queue_method' do
      expect_new_config_to_raise_error( { 'queue_method' => 'blah' }, WorkerConfig, 'Invalid queue_method given ("blah"). Must be one of ["polling", "signals"].' )
    end

    describe 'should handle queue_method == "polling"' do

      describe 'polling specific attributes should default when not provided' do

        before( :all ) do

          specific_attributes = @attribute_hashes[ :all_polling ]
          specific_attributes.delete( 'polling_timing' )
          specific_attributes.delete( 'polling_delay_seonds' )
          specific_attributes.delete( 'polling_delay_stdev' )

          @temp_file = create_temp_config_file( 'temp', specific_attributes )
          @conf = WorkerConfig.new( @temp_file.path )
        end

        after( :all ) do
          cleanup_temp_config_file( @temp_file )
        end

        it 'should default polling_timing to "randomized"' do
          expect( @conf[ 'polling_timing' ] ).to eq( 'randomized' )
        end

        it 'should default polling_delay_seconds to 1.0' do
          expect( @conf[ 'polling_delay_seconds' ] ).to eq( 1.0 )
        end

        it 'should default polling_delay_stdev to 0.25' do
          expect( @conf[ 'polling_delay_stdev' ] ).to eq( 0.25 )
        end

      end

      describe 'polling specific attributes should be honored when provided' do

        before( :each ) do
          @specific_attributes = Hash.new
          @specific_attributes[ 'queue_method'          ] = 'polling'
          @specific_attributes[ 'polling_timing'        ] = 'randomized'
          @specific_attributes[ 'polling_delay_seconds' ] = 10.0
          @specific_attributes[ 'polling_delay_stdev'   ] = 3.0
        end

        it 'should honor polling_timing == "randomized"' do

          with_config( @specific_attributes, WorkerConfig ) do |conf|
            expect( conf[ 'polling_timing' ] ).to eq( 'randomized' )
          end

        end

        it 'should honor polling_timing == "absolute"' do

          @specific_attributes[ 'polling_timing' ] = 'absolute'

          with_config( @specific_attributes, WorkerConfig ) do |conf|
            expect( conf[ 'polling_timing' ] ).to eq( 'absolute' )
          end

        end

        it 'should raise an exception if any value other than "absolute" or "randomized" is provided for polling_timing' do

          @specific_attributes[ 'polling_timing' ] = 'fubar'

          expect_new_config_to_raise_error( @specific_attributes, WorkerConfig, 'Invalid polling_timing given ("fubar"). Must be one of ["absolute", "randomized"].' )

        end

        it 'should honor specific values being provided for polling_delay_seconds' do

          with_config( @specific_attributes, WorkerConfig ) do |conf|
            expect( conf[ 'polling_delay_seconds' ] ).to eq( 10.0 )
          end

        end

        it 'should honor specific values being provided for polling_delay_stdev' do

          with_config( @specific_attributes, WorkerConfig ) do |conf|
            expect( conf[ 'polling_delay_stdev' ] ).to eq( 3.0 )
          end

        end

        it 'should require polling_delay_seconds to be a floating point number when provided' do

          @specific_attributes[ 'polling_delay_seconds' ] = 'fubar'

          expect_new_config_to_raise_error( @specific_attributes, WorkerConfig, 'invalid value for Float(): "fubar"' )

        end

        it 'should require polling_delay_stdev to be a floating point number when provided' do

          @specific_attributes[ 'polling_delay_stdev' ] = 'fubar'

          expect_new_config_to_raise_error( @specific_attributes, WorkerConfig, 'invalid value for Float(): "fubar"' )

        end

      end

    end

    describe 'should handle queue_method == "signals"' do

      it  'should not default any polling values' do

        with_config( @attribute_hashes[ :all_signals ], WorkerConfig ) do |conf|
          expect( conf[ 'polling_timing' ] ).to be_nil
          expect( conf[ 'polling_delay_seconds' ] ).to be_nil
          expect( conf[ 'polling_delay_stdev' ] ).to be_nil
        end

      end

      it 'should not validate any polling values (because in signals mode they will be ignored).' do
        specific_attributes = @attribute_hashes[ :all_signals ].dup

        specific_attributes[ 'polling_timing'        ] = 'foo'
        specific_attributes[ 'polling_delay_seconds' ] = 'bar'
        specific_attributes[ 'polling_delay_stdev'   ] = 'bam'

        with_config( specific_attributes, WorkerConfig ) do |conf|
          expect( conf[ 'polling_timing' ] ).to eq( 'foo' )
          expect( conf[ 'polling_delay_seconds' ] ).to eq( 'bar' )
          expect( conf[ 'polling_delay_stdev' ] ).to eq( 'bam' )
        end

      end

    end

  end

end
