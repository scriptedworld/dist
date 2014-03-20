
require 'config/baseconfig'

class ReporterConfig < BaseConfig

  def validate
    super

    validateKeysExist( @attributes, *( %w( report_interval_seconds ) ) )
    @attributes[ 'report_interval_seconds' ] = Float( @attributes[ 'report_interval_seconds' ] )
  end

end



