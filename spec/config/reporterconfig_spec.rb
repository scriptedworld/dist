require 'spec_helper'
require 'config/reporterconfig'

describe "Reporter Configuration Files" do

  include ConfigHelpers

  before( :all ) do

    @all_attributes = Hash.new
    @all_attributes[ 'report_interval_seconds' ] = 10.0

    @attribute_hashes = Hash.new
    @attribute_hashes[ :all ] = @all_attributes
    @attribute_hashes[ :empty ] = Hash.new

  end

  it "should be derived from BaseConfig" do
    kindOfBaseConfig( @attribute_hashes[ :all ], ReporterConfig, :include_base_attributes => true )
  end

  it "requires a report_interval_seconds parameter" do
    expectNewConfigToRaiseError( @attribute_hashes[ :empty ], ReporterConfig, "Key report_interval_seconds missing.", :include_base_attributes => true )
  end

  it "requires the report_interval_seconds parameter to be a float compatible value." do
    expectNewConfigToRaiseError( { 'report_interval_seconds' => 'foo' }, ReporterConfig, "invalid value for Float(): \"foo\"", :include_base_attributes => true )
  end

end

