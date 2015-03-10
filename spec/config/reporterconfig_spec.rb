require 'spec_helper'
require 'dist/config/reporterconfig'

module Dist

  describe 'Reporter Configuration Files' do

    include Helpers
    include ConfigHelpers

    before( :all ) do

      @all_attributes = {}
      @all_attributes[ 'report_interval_seconds' ] = 10.0

      @attribute_hashes = {}
      @attribute_hashes[ :all ] = @all_attributes
      @attribute_hashes[ :empty ] = {}

    end

    it 'should be derived from BaseConfig' do
      kind_of_baseconfig( @attribute_hashes[ :all ], ReporterConfig )
    end

    it 'requires a report_interval_seconds parameter' do
      expect_new_config_to_raise_error( @attribute_hashes[ :empty ], ReporterConfig, 'Key report_interval_seconds missing.' )
    end

    it 'requires the report_interval_seconds parameter to be a float compatible value.' do
      expect_new_config_to_raise_error( { 'report_interval_seconds' => 'foo' }, ReporterConfig, 'invalid value for Float(): "foo"' )
    end

  end

end
