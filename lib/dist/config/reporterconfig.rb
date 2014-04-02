
require 'dist/config/baseconfig'

module Dist

  class ReporterConfig < BaseConfig

    def validate
      super

      validate_keys_exist( @attributes, *( %w( report_interval_seconds ) ) )
      @attributes[ 'report_interval_seconds' ] = Float( @attributes[ 'report_interval_seconds' ] )
    end

  end

end
