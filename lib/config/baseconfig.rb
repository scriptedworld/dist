
require 'helpers'

class BaseConfig

  REQUIRED_ATTRIBUTES = %w( name log_dir redis_host redis_port redis_pass debug )

  def []( key )
    @attributes[ key ]
  end

  def []=( key, value )
    @attributes[ key ] = value
  end

  def include?( key )
    @attributes.include?( key )
  end

  def initialize( file_path )
    @attributes = loadYAMLFile( file_path )
    validate()
    # Finally, ensure debug if @attribute provided, otherwise, leave the value alone.
    $DEBUG = @attributes[ 'debug' ] if @attributes[ 'debug' ]
  end

  # NOTE: This method should raise an Exception if anything is wrong.
  def validate
    validateKeysExist( @attributes, *REQUIRED_ATTRIBUTES )
  end

end

