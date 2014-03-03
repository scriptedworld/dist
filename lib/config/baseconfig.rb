
require './lib/helpers.rb'

class BaseConfig

  def []( key )
    @attributes[ key ]
  end

  def []=( key, value )
    @attributes[ key ] = value
  end

  def initialize( file_path )
    @attributes = loadYAMLFile( file_path )
    validate()
    # Finally, set debug based on passed in value.
    $DEBUG = @attributes[ 'debug' ]
  end

  def validate
    validateKeysExist( @attributes, *( %w( name log_dir redis_host redis_port redis_pass debug ) ) )
  end

end

