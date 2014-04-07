
require 'dist/helpers'

module Dist

  module DebugHelpers

    include Helpers

    def preset_debug_state_and_validate_result( pre_debug_state, expected_debug_state, &block )

      old_state = $DEBUG
      $DEBUG = pre_debug_state

      yield

      result = ( $DEBUG == expected_debug_state )

      $DEBUG = old_state

      result

    end

    def test_debug_state( before_state, after_state, config_file_path, config_class = BaseConfig )
      expect(
        preset_debug_state_and_validate_result( before_state, after_state ) do
          with_temp_file_from_attributes( config_attributes ) do |temp_file|
            config_class.new( temp_file.path )
          end
        end
      ).to be_true
    end

  end

end
