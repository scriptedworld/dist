require 'spec_helper'
require 'dist/config/workerconfig'

module Dist

  describe "Worker Configuration Files" do

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

    it "should be derived from BaseConfig" do
      kindOfBaseConfig( @attribute_hashes[ :all_polling ], WorkerConfig, :include_base_attributes => true )
    end

    it "requires a queue_method parameter" do
      expectNewConfigToRaiseError( @attribute_hashes[ :empty ], WorkerConfig, "Key queue_method missing.", :include_base_attributes => true )
    end

    it "should raise an exception if any value other than 'polling' or 'signals' is provided for queue_method" do
      expectNewConfigToRaiseError( { 'queue_method' => 'blah' }, WorkerConfig, "Invalid queue_method given ('blah'). Must be one of [\"polling\", \"signals\"].", :include_base_attributes => true )
    end

    describe "should handle queue_method == 'polling'" do

      describe "polling specific attributes should default when not provided" do

        before( :all ) do

          specific_attributes = @attribute_hashes[ :all_polling ]
          specific_attributes.delete( 'polling_timing' )
          specific_attributes.delete( 'polling_delay_seonds' )
          specific_attributes.delete( 'polling_delay_stdev' )

          @temp_file = createTempConfigFile( 'temp', specific_attributes, :include_base_attributes => true )
          @conf = WorkerConfig.new( @temp_file.path )
        end

        after( :all ) do
          cleanupTempConfigFile( @temp_file )
        end

        it "should default polling_timing to 'randomized'" do
          expect( @conf[ 'polling_timing' ] ).to eq( 'randomized' )
        end

        it "should default polling_delay_seconds to 1.0" do
          expect( @conf[ 'polling_delay_seconds' ] ).to eq( 1.0 )
        end

        it "should default polling_delay_stdev to 0.25" do
          expect( @conf[ 'polling_delay_stdev' ] ).to eq( 0.25 )
        end

      end

      describe "polling specific attributes should be honored when provided" do

        before( :each ) do
          @specific_attributes = Hash.new
          @specific_attributes[ 'queue_method'          ] = 'polling'
          @specific_attributes[ 'polling_timing'        ] = 'randomized'
          @specific_attributes[ 'polling_delay_seconds' ] = 10.0
          @specific_attributes[ 'polling_delay_stdev'   ] = 3.0
        end

        it "should honor polling_timing == 'randomized'" do

          withConfig( @specific_attributes, WorkerConfig, :include_base_attributes => true ) do |conf|
            expect( conf[ 'polling_timing' ] ).to eq( 'randomized' )
          end

        end

        it "should honor polling_timing == 'absolute'" do

          @specific_attributes[ 'polling_timing' ] = 'absolute'

          withConfig( @specific_attributes, WorkerConfig, :include_base_attributes => true ) do |conf|
            expect( conf[ 'polling_timing' ] ).to eq( 'absolute' )
          end

        end

        it "should raise an exception if any value other than 'absolute' or 'randomized' is provided for polling_timing" do

          @specific_attributes[ 'polling_timing' ] = 'fubar'

          expectNewConfigToRaiseError( @specific_attributes, WorkerConfig, "Invalid polling_timing given ('fubar'). Must be one of [\"absolute\", \"randomized\"].", :include_base_attributes => true )

        end

        it "should honor specific values being provided for polling_delay_seconds" do

          withConfig( @specific_attributes, WorkerConfig, :include_base_attributes => true ) do |conf|
            expect( conf[ 'polling_delay_seconds' ] ).to eq( 10.0 )
          end

        end

        it "should honor specific values being provided for polling_delay_stdev" do

          withConfig( @specific_attributes, WorkerConfig, :include_base_attributes => true ) do |conf|
            expect( conf[ 'polling_delay_stdev' ] ).to eq( 3.0 )
          end

        end

        it "should require polling_delay_seconds to be a floating point number when provided" do

          @specific_attributes[ 'polling_delay_seconds' ] = 'fubar'

          expectNewConfigToRaiseError( @specific_attributes, WorkerConfig, "invalid value for Float(): \"fubar\"", :include_base_attributes => true )

        end

        it "should require polling_delay_stdev to be a floating point number when provided" do

          @specific_attributes[ 'polling_delay_stdev' ] = 'fubar'

          expectNewConfigToRaiseError( @specific_attributes, WorkerConfig, "invalid value for Float(): \"fubar\"", :include_base_attributes => true )

        end

      end

    end

    describe "should handle queue_method == 'signals'" do

      it  "should not default any polling values" do

        withConfig( @attribute_hashes[ :all_signals ], WorkerConfig, :include_base_attributes => true ) do |conf|
          expect( conf[ 'polling_timing' ] ).to be_nil
          expect( conf[ 'polling_delay_seconds' ] ).to be_nil
          expect( conf[ 'polling_delay_stdev' ] ).to be_nil
        end

      end

      it "should not validate any polling values (because in signals mode they will be ignored)." do
        specific_attributes = @attribute_hashes[ :all_signals ].dup

        specific_attributes[ 'polling_timing'        ] = 'foo'
        specific_attributes[ 'polling_delay_seconds' ] = 'bar'
        specific_attributes[ 'polling_delay_stdev'   ] = 'bam'

        withConfig( specific_attributes, WorkerConfig, :include_base_attributes => true ) do |conf|
          expect( conf[ 'polling_timing' ] ).to eq( 'foo' )
          expect( conf[ 'polling_delay_seconds' ] ).to eq( 'bar' )
          expect( conf[ 'polling_delay_stdev' ] ).to eq( 'bam' )
        end

      end

    end

  end

end
