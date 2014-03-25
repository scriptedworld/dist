
require 'dist/config/baseconfig'

module Dist

  class ReporterConfig < BaseConfig

    def validate
      super

      validateKeysExist( @attributes, *( %w( report_interval_seconds ) ) )
      @attributes[ 'report_interval_seconds' ] = Float( @attributes[ 'report_interval_seconds' ] )
    end

  end

end


