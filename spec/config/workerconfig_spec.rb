require 'spec_helper'
require 'config/workerconfig'

describe "Worker Configuration Files" do

  include ConfigHelpers

  before( :all ) do

    @all_attributes_polling                            = Hash.new
    @all_attributes_polling[ 'queue_method'          ] = 'polling'
    @all_attributes_polling[ 'polling_timing'        ] = 'randomized'
    @all_attributes_polling[ 'polling_delay_seconds' ] = 1.0
    @all_attributes_polling[ 'polling_delay_stdev'   ] = 0.25

    @all_attributes_signals                            = Hash.new
    @all_attributes_signals[ 'queue_method'          ] = 'signals'

    @temp_files = Hash.new
    @temp_files[ 'all_polling' ] = createAdvancedTempConfig( 'all_polling', @all_attributes_polling )
    @temp_files[ 'all_signals' ] = createAdvancedTempConfig( 'all_signals', @all_attributes_signals )
    @temp_files[ 'empty'       ] = createAdvancedTempConfig( 'empty' )

  end

  after( :all ) do
    cleanupTempConfigList( @temp_files.values )
  end

  it "should be derived from BaseConfig" do
    conf = WorkerConfig.new( @temp_files[ 'all_polling' ].path )
    conf.should be_a( BaseConfig )
  end

  it "requires a queue_method parameter" do

    expect { WorkerConfig.new( @temp_files[ 'empty' ].path ) }.to raise_error( "Key queue_method missing." )

  end

  it "should raise an exception if any value other than 'polling' or 'signals' is provided for queue_method" do

    withAdvancedTempConfigBasedOnAttributes( { 'queue_method' => 'blah' } ) do |temp_file|

      expect { WorkerConfig.new( temp_file.path ) }.to raise_error( "Invalid queue_method given ('blah'). Must be one of [\"polling\", \"signals\"]." )

    end

  end

  describe "should handle queue_method == 'polling'" do

    describe "polling specific attributes should default when not provided" do

      before( :all ) do
        @temp_file = createAdvancedTempConfig( 'temp', { 'queue_method' => 'polling' } )
        @conf = WorkerConfig.new( @temp_file.path )
      end

      after( :all ) do
        cleanupTempConfig( @temp_file )
      end

      it "should default polling_timing to 'randomized'" do
        @conf[ 'polling_timing' ].should == 'randomized'
      end

      it "should default polling_delay_seconds to 1.0" do
        @conf[ 'polling_delay_seconds' ].should == 1.0
      end

      it "should default polling_delay_stdev to 0.25" do
        @conf[ 'polling_delay_stdev' ].should == 0.25
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

        withAdvancedTempConfigBasedOnAttributes( @specific_attributes ) do |temp_file|

          conf = WorkerConfig.new( temp_file.path )
          conf[ 'polling_timing' ].should == 'randomized'

        end

      end

      it "should honor polling_timing == 'absolute'" do

        @specific_attributes[ 'polling_timing' ] = 'absolute'

        withAdvancedTempConfigBasedOnAttributes( @specific_attributes ) do |temp_file|
          conf = WorkerConfig.new( temp_file.path )
          conf[ 'polling_timing' ].should == 'absolute'
        end

      end

      it "should raise an exception if any value other than 'absolute' or 'randomized' is provided for polling_timing" do

        @specific_attributes[ 'polling_timing' ] = 'fubar'

        withAdvancedTempConfigBasedOnAttributes( @specific_attributes ) do |temp_file|
          expect { WorkerConfig.new( temp_file.path ) }.to raise_error( "Invalid polling_timing given ('fubar'). Must be one of [\"absolute\", \"randomized\"]." )
        end

      end

      it "should honor specific values being provided for polling_delay_seconds" do

        withAdvancedTempConfigBasedOnAttributes( @specific_attributes ) do |temp_file|
          conf = WorkerConfig.new( temp_file.path )
          conf[ 'polling_delay_seconds' ].should == 10.0
        end

      end

      it "should honor specific values being provided for polling_delay_stdev" do

        withAdvancedTempConfigBasedOnAttributes( @specific_attributes ) do |temp_file|
          conf = WorkerConfig.new( temp_file.path )
          conf[ 'polling_delay_stdev' ].should == 3.0
        end

      end

      it "should require polling_delay_seconds to be a floating point number when provided" do

        @specific_attributes[ 'polling_delay_seconds' ] = 'fubar'

        withAdvancedTempConfigBasedOnAttributes( @specific_attributes ) do |temp_file|
          expect { WorkerConfig.new( temp_file.path ) }.to raise_error( "invalid value for Float(): \"fubar\"" )
        end

      end

      it "should require polling_delay_stdev to be a floating point number when provided" do

        @specific_attributes[ 'polling_delay_stdev' ] = 'fubar'

        withAdvancedTempConfigBasedOnAttributes( @specific_attributes ) do |temp_file|
          expect { WorkerConfig.new( temp_file.path ) }.to raise_error( "invalid value for Float(): \"fubar\"" )
        end

      end

    end

  end

  describe "should handle queue_method == 'signals'" do

    it  "should not default any polling values" do

      withAdvancedTempConfigBasedOnAttributes( @all_attributes_signals ) do |temp_file|
        conf = WorkerConfig.new( temp_file.path )
        conf[ 'polling_timing' ].should be_nil
        conf[ 'polling_delay_seconds' ].should be_nil
        conf[ 'polling_delay_stdev' ].should be_nil
      end

    end

    it "should not validate any polling values (because in signals mode they will be ignored)." do
      specific_attributes = @all_attributes_signals.dup

      specific_attributes[ 'polling_timing'        ] = 'foo'
      specific_attributes[ 'polling_delay_seconds' ] = 'bar'
      specific_attributes[ 'polling_delay_stdev'   ] = 'bam'

      withAdvancedTempConfigBasedOnAttributes( specific_attributes ) do |temp_file|
        conf = WorkerConfig.new( temp_file.path )
        conf[ 'polling_timing'        ].should == 'foo'
        conf[ 'polling_delay_seconds' ].should == 'bar'
        conf[ 'polling_delay_stdev'   ].should == 'bam'
      end

    end

  end

end
