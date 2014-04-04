
require 'dist/helpers'
require 'dist/app/baseapp'
require 'dist/config/runnerconfig'

module Dist

  class RunnerPhaseHandler

    include Helpers
    include Logged

    def initialize( phase_config, runner_config )

      @phase_config = phase_config
      @runner_config = runner_config

      @job_count    = 0
      @time_elapsed = 0
      @job_elapsed  = Hash.new( 0 )
      @job_delays   = Hash.new( 0 )
      @job_rates    = Hash.new( 0 )

      @max_job_count = @phase_config.key?( 'total_count' ) ? @phase_config[ 'total_count' ] : -1
      display_debug_message( "Max Count: #{ @max_job_count }" )

      @max_time_elapsed = @phase_config.key?( 'phase_duration' ) ? ( @phase_config[ 'phase_duration' ] * TIME_UNITS[ @phase_config[ 'phase_duration_units' ] ] ) : -1
      display_debug_message( "Max Duration: #{ @max_time_elapsed }" )

      # setup initial rates for each job type within this phase.
      @phase_config[ 'jobs' ].each do |curr_job|
        curr_job_class = curr_job[ 'job_class' ]
        @job_rates[ curr_job_class ] = rate_per_second( curr_job[ 'per_unit' ], curr_job[ 'unit' ] )
        @job_delays[ curr_job_class ] = 1000 / @job_rates[ curr_job_class ]
        @job_elapsed[ curr_job_class ] = 0
      end

    end

    def phase_complete?

      max_jobs_reached = false
      max_jobs_reached = ( @job_count >= @max_job_count ) unless @max_job_count == -1

      max_time_reached = false
      max_time_reached = ( @time_elapsed >= @max_time_elapsed ) unless @max_time_elapsed == -1

      max_jobs_reached || max_time_reached

    end

    def process_job_type( job_config )

      curr_class   = job_config[ 'job_class' ]
      curr_elapsed = @job_elapsed[ curr_class ]
      curr_rate    = @job_rates[ curr_class ]
      curr_delay   = @job_delays[ curr_class ]

      curr_elapsed += @cycle_elapsed

      if curr_elapsed >= curr_delay
        curr_elapsed -= curr_delay

        # TODO: We should check for instance specific attributes to merge in on top of the base_attributes collection.

        # Schedule a job.
        schedule_job( job_config, @runner_config[ 'base_attributes' ] )

        if @runner_config[ 'use_poisson' ]
          curr_delay = calculate_poisson( curr_rate )
          @job_delays[ curr_class ] = curr_delay
        end

        # Deal with the possibility of having created enough jobs or
        # having had enough time elapsed for this phase.
        @job_count += 1

        display_debug_message( "#{ curr_class }: Next delay #{ curr_delay }ms" )
      end

      @job_elapsed[ curr_class ] = curr_elapsed

    end

    def schedule_job( job_info, base_attributes = {} )
      attributes = {}
      attributes[ 'job_class' ] = job_info[ 'job_class' ]
      attributes.merge!( base_attributes ) unless base_attributes.nil?

      j = Job.new
      j.job_data = attributes
      j.save

      j.state = 'READY'
      j.signal_ready
    end

    def calculate_poisson( desired_rate_per_second )
      # Wait duration in Milliseconds
      ( -( Math.log( 1 - Kernel.rand ) ) / desired_rate_per_second ) * 1000
    end

    def rate_per_second( rate, interval_name )
      1000 / ( TIME_UNITS[ interval_name ] / rate )
    end

    def run
      record_run_event( "Phase #{ @runner_config[ 'name' ] }::#{ @phase_config[ 'name' ] }: START" )
      display_debug_message( "Starting Phase: #{ @phase_config[ 'name' ] }." )

      until phase_complete?

        @current_time = Time.now.to_f
        @last_time ||= @current_time

        @cycle_elapsed = ( @current_time - @last_time ) * 1000

        # Wait until at least a millisecond has passed.
        next unless @cycle_elapsed > 1.0

        @last_time = @current_time

        @time_elapsed += @cycle_elapsed

        @phase_config[ 'jobs' ].map { |curr_job| process_job_type( curr_job ) }

      end

      record_run_event( "Phase #{ @runner_config[ 'name' ] }::#{ @phase_config[ 'name' ] }: STOP" )
    end

  end

  class RunnerApp < BaseApp

    def config_class
      RunnerConfig
    end

    def instance_run

      record_run_event( "Test #{ @config[ 'name' ] }: START" )

      infinite_loop = true
      loop_count = 0
      while infinite_loop

        @config[ 'phases' ].each { |curr_phase| RunnerPhaseHandler.new( curr_phase, @config ).run }

        # Handle the 'continuous' @config value.

        if @config[ 'continuous' ] == true
          record_run_event( "Phase loop ##{ loop_count } complete. Continuous mode restarting phase cycle." )
          loop_count += 1
        else
          infinite_loop = false
        end

      end

      record_run_event( "Test #{ @config[ 'name' ] }: STOP" )

    end

  end

end
