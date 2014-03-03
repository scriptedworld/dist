
require './lib/helpers.rb'
require './lib/config/baseconfig.rb'

class WorkerConfig < BaseConfig

  def validate
    super

    allowed_timings = %w( absolute randomized )
    allowed_queue_methods = %w( polling signals )

    validateKeysExist( @attributes, *( %w( queue_method ) ) )

    # queue_method controls if a worker will try to use waitForSignal or simply poll and sleep. ( This sleep will be affected by the following optional configuration values )
    raise "Invalid queue method given ('#{ @attributes[ 'queue_method' ] }'). Must be one of #{ allowed_queue_methods }." unless allowed_queue_methods.include?( @attributes[ 'queue_method' ] )

    if( @attributes[ 'queue_method' ] == 'polling' )

      # Do we want to randomize the timing of the polling wait timer? 
      if( @attributes.key?( 'polling_timing' ) )
        raise "Invalid polling_timing type given ('#{ @attributes[ 'polling_timing' ] }'). Must be one of #{ allowed_timings }." unless allowed_timings.include?( @attributes[ 'polling_timing' ] )
      else
        @attributes[ 'polling_timing' ] = 'randomized'
      end

      # polling_delay_seconds is only considered *IF* a user has requested to use polling instead of signals.
      if( @attributes.key?( 'polling_delay_seconds' ) )
         @attributes[ 'polling_delay_seconds' ] = Float( @attributes[ 'polling_delay_seconds' ] )
      else
         @attributes[ 'polling_delay_seconds' ] = 1.0 # If polling_delay_seconds is not provided, default to a 1.0 sec sleep timer value.
      end

      # STDEV value to use when working with randomized poll timings.
      if( @attributes.key?( 'polling_delay_stdev' ) )
         @attributes[ 'polling_delay_stdev' ] = Float( @attributes[ 'polling_delay_stdev' ] )
      else
         @attributes[ 'polling_delay_stdev' ] = 0.25 # If polling_delay_stdev is not provided, default to a 0.25 value which is based on the above default of 1.0 sec..
      end
    end

  end

end

