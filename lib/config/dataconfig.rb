
require './lib/config/baseconfig.rb'

class DataConfig < BaseConfig

  def validate
    super

    validateKeysExist( @attributes, *( %w( web_address web_port graph_background_image graph_index_format ) ) )

    # TODO: validate that the path given for graph_background_image is VALID.

    @attributes[ 'web_port' ]             = Integer( @attributes[ 'web_port' ] )

  end

end
