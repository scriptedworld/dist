
require 'dist/helpers'

module Dist

  module DebugHelpers

    include Helpers

    def presetDebugStateAndValidateResult( pre_debug_state, expected_debug_state, &block )

      old_state = $DEBUG
      $DEBUG = pre_debug_state

      yield

      result = ( $DEBUG == expected_debug_state )

      $DEBUG = old_state

      result

    end

    def testDebugState( before_state, after_state, config_file_path, config_class = BaseConfig )
      expect {
        presetDebugStateAndValidateResult( before_state, after_state ) do
          withTempFileFromAttributes( config_attributes ) do |temp_file|
            config_class.new( temp_file.path )
          end
        end
      }.to be_true
    end

  end

end
