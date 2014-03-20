
require 'tempfile'
require 'yaml'

module ConfigHelpers

  def createTempConfig( name, from_hash = {} )

    temp_file = Tempfile.new( "#{ name }.yaml" )
    temp_file.write( from_hash.to_yaml )
    temp_file.close

    temp_file

  end

  def cleanupTempConfig( temp_file )
    temp_file.unlink
  end

  def cleanupTempConfigList( temp_file_list = [] )
    temp_file_list.each do |curr_temp_file|
      curr_temp_file.unlink
    end
  end

  def getBaseConfigHash()

    {
      'name'       => 'config name',
      'redis_host' => 'localhost',
      'redis_port' => 6379,
      'redis_pass' => 'slenderman',
      'log_dir'    => './',
      'debug'      => false
    }

  end

  def createAdvancedTempConfig( name, additional_params = {} )

    attributes = {}
    attributes.merge! getBaseConfigHash
    attributes.merge! additional_params

    createTempConfig( name, attributes )

  end

  def withAdvancedTempConfigBasedOnAttributes( attributes )

    temp_file = createAdvancedTempConfig( 'temp', attributes )

    yield temp_file

    cleanupTempConfig( temp_file )

  end

end
