
require 'dist/config/baseconfig'

module Dist

  class WorkerConfig < BaseConfig

    def enforce_attribute_float_with_default( attribute_name, default_value )
      if @attributes.key?( attribute_name )
        @attributes[ attribute_name ] = Float( @attributes[ attribute_name ] )
      else
        @attributes[ attribute_name ] = Float( default_value )
      end
    end

    def enforce_string_within_allowed_set( attribute_name, allowed_values )
      given_value = @attributes[ attribute_name ]
      assert_includes( allowed_values, given_value, "Invalid #{ attribute_name } given (\"#{ given_value }\"). Must be one of #{ allowed_values }." )
    end

    def validate
      super

      allowed_timings = %w( absolute randomized )
      allowed_queue_methods = %w( polling signals )

      validate_keys_exist( @attributes, *( %w( queue_method ) ) )

      # queue_method controls if a worker will try to use wait_for_signal or simply poll and sleep. ( This sleep will be affected by the following optional configuration values )
      enforce_string_within_allowed_set( 'queue_method', allowed_queue_methods )

      if @attributes[ 'queue_method' ] == 'polling'

        # Do we want to randomize the timing of the polling wait timer?
        if @attributes.key?( 'polling_timing' )
          enforce_string_within_allowed_set( 'polling_timing', allowed_timings )
        else
          @attributes[ 'polling_timing' ] = 'randomized'
        end

        # polling_delay_seconds is only considered *IF* a user has requested to use polling instead of signals.
        enforce_attribute_float_with_default( 'polling_delay_seconds', 1.0 )

        # STDEV value to use when working with randomized poll timings.
        enforce_attribute_float_with_default( 'polling_delay_stdev', 0.25 )

      end

    end

  end

end
