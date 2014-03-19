require './spec/spec_helper.rb'
require './lib/config/reporterconfig.rb'

require 'Tempfile'

describe "Reporter Configuration Files" do

  before( :all ) do

    @all_attributes = Hash.new
    @all_attributes[ 'report_interval_seconds' ] = 10.0

    @temp_files = Hash.new
    @temp_files[ 'all'   ] = ConfigHelpers.createAdvancedTempConfig( 'all', @all_attributes )
    @temp_files[ 'empty' ] = ConfigHelpers.createAdvancedTempConfig( 'empty' )

  end

  after( :all ) do
    ConfigHelpers.cleanupTempConfigList( @temp_files.values )
  end

  it "should be derived from BaseConfig" do

    conf = ReporterConfig.new( @temp_files[ 'all' ].path )
    conf.should be_a( BaseConfig )

  end

  it "requires a report_interval_seconds parameter" do

    expect { ReporterConfig.new( @temp_files[ 'empty' ].path ) }.to raise_error( "Key report_interval_seconds missing." )

  end

  it "requires the report_interval_seconds parameter to be a float compatible value." do

    specific_attributes = Hash.new
    specific_attributes[ 'report_interval_seconds' ] = 'foo'

    ConfigHelpers.withAdvancedTempConfigBasedOnAttributes( specific_attributes ) do |temp_file|
      expect { ReporterConfig.new( temp_file.path ) }.to raise_error( "invalid value for Float(): \"foo\"" )
    end

  end

end

