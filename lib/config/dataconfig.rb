
require 'config/baseconfig'

class DataConfig < BaseConfig

  def validate
    super

    validateKeysExist( @attributes, *( %w( graph_background_image graph_index_format ) ) )

    # TODO: validate that the path given for graph_background_image is VALID.

  end

end
