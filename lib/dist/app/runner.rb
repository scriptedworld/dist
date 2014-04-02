
require 'dist/app/baseapp'
require 'dist/config/runnerconfig'

module Dist

  class RunnerApp < BaseApp

    def record_run_event( event_name, additional_data = {} )
      event_store = EventStore.new

      new_id = event_store.get_new_item_id

      attributes = {}
      attributes.merge!( additional_data )
      attributes[ 'name' ] = event_name
      attributes[ 'timestamp' ] = Time.now.to_f

      event_store.save_item( new_id, attributes )
    end

    def schedule_job( job_info, base_attributes = {} )
      attributes = {}
      attributes[ 'job_class' ] = job_info[ 'job_class' ]
      attributes.merge!( base_attributes ) unless base_attributes.nil?

      j = Job.new
      j.set_attributes( attributes )
      j.save

      j.set_state( 'READY' )
      j.signal_ready
    end

    def calculate_poisson( desired_rate_per_second )
      # Wait duration in Milliseconds
      ( -( Math.log( 1 - Kernel.rand ) ) / desired_rate_per_second ) * 1000
    end

    def rate_per_second( rate, interval_name )
      1000 / ( TIME_UNITS[ interval_name ] / rate )
    end

    def get_config_class
      RunnerConfig
    end

    def handle_phase( curr_phase )

      record_run_event( "Phase #{ $config[ 'name' ] }::#{ curr_phase[ 'name' ] }: START" )

      display_debug_message( "Starting Phase: #{ curr_phase[ 'name' ] }." )

      phase_job_count = 0
      phase_time_elapsed = 0

      phase_max_job_count = curr_phase.key?( 'total_count' ) ? curr_phase[ 'total_count' ] : -1
      phase_max_time_elapsed = curr_phase.key?( 'phase_duration' ) ? ( curr_phase[ 'phase_duration' ] * TIME_UNITS[ curr_phase[ 'phase_duration_units' ] ] ) : -1

      job_elapsed = Hash.new( 0 )
      job_delays = Hash.new( 0 )
      job_rates = Hash.new( 0 )

      # setup for the first run of each job type
      curr_phase[ 'jobs' ].each do |curr_job|
        curr_job_class = curr_job[ 'job_class' ]
        job_rates[ curr_job_class ] = rate_per_second( curr_job[ 'per_unit' ], curr_job[ 'unit' ] )
        job_delays[ curr_job_class ] = 1000 / job_rates[ curr_job_class ]
        job_elapsed[ curr_job_class ] = 0
      end

      display_debug_message( "Max Count: #{ phase_max_job_count }" )
      display_debug_message( "Max Duration: #{ phase_max_time_elapsed }" )

      stop = false

      until stop

        current_time = Time.now.to_f
        last_time ||= current_time

        elapsed = ( current_time - last_time ) * 1000

        # Wait until at least a millisecond has passed.
        next unless elapsed > 1.0

        last_time = current_time

        phase_time_elapsed += elapsed

        curr_phase[ 'jobs' ].each do |curr_job|
          curr_class   = curr_job[ 'job_class' ]
          curr_elapsed = job_elapsed[ curr_class ]
          curr_rate    = job_rates[ curr_class ]
          curr_delay   = job_delays[ curr_class ]

          curr_elapsed += elapsed

          if curr_elapsed >= curr_delay
            curr_elapsed -= curr_delay

            # TODO: We should check for instance specific attributes to merge in on top of the base_attributes collection.

            # Schedule a job.
            schedule_job( curr_job, $config[ 'base_attributes' ] )

            if $config[ 'use_poisson' ]
              curr_delay = calculate_poisson( curr_rate )
              job_delays[ curr_class ] = curr_delay
            end

            # Deal with the possibility of having created enough jobs or
            # having had enough time elapsed for this phase.
            phase_job_count += 1

            display_debug_message( "#{ curr_class }: Next delay #{ curr_delay }ms" )
          end

          job_elapsed[ curr_class ] = curr_elapsed

          # If I'm tracking job count for the phase ...
          unless phase_max_job_count == -1
            stop = phase_job_count >= phase_max_job_count
            next
          end

          # If I'm tracking time elapsed for the phase ...
          unless phase_max_time_elapsed == -1
            stop = phase_time_elapsed >= phase_max_time_elapsed
            next
          end

        end

      end

      record_run_event( "Phase #{ $config[ 'name' ] }::#{ curr_phase[ 'name' ] }: STOP" )

    end

    def instance_run

      record_run_event( "Test #{ $config[ 'name' ] }: START" )

      infinite_loop = true
      loop_count = 0
      while infinite_loop

        $config[ 'phases' ].each { |curr_phase| handle_phase( curr_phase ) }

        # Handle the 'continuous' $config value.

        if $config[ 'continuous' ] == true
          record_run_event( "Phase loop ##{ loop_count } complete. Continuous mode restarting phase cycle." )
          loop_count += 1
        else
          infinite_loop = false
        end

      end

      record_run_event( "Test #{ $config[ 'name' ] }: STOP" )

    end

  end

end
