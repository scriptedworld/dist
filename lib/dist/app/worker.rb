
require 'dist/app/baseapp'
require 'dist/config/workerconfig'
require 'dist/store/jobstore'

module Dist

  class WorkerApp < BaseApp

    def wait_for_job_via_signalling
      display_debug_message( 'No jobs ready, waiting for signal.' )
      @j.wait_for_item_ready_signal
    end

    def wait_for_job_via_polling
      wait_seconds( @config[ 'polling_delay_seconds' ], ( @config[ 'polling_timing' ] == 'absolute' ), @config[ 'polling_delay_stdev' ] )
    end

    def next_ready_job

      parts = @j.get_item_id_from_state( 'READY' )

      job_id = parts.nil? ? nil : parts[0]
      output = nil

      if ( job_id.is_a?( String ) ) && ( job_id.start_with?( @j.item_prefix ) )

        job_attributes = @j.load_item( job_id )
        job_class = job_attributes[ 'job_class' ]

        job_klass = Object.const_get( job_class )
        raise "Inappropriate job_class provided: #{ job_class }" unless job_klass.ancestors.include?( Job )

        # Since I've already loaded the attributes for this job, I don't need to do
        # it again. Build our Job object instead of letting the constructor
        # duplicate the work done above.
        output = job_klass.new
        output.job_id   = job_id
        output.job_data = job_attributes

      else

        # See below, waitForJob is an alias.
        waitForJob

      end

      output

    end

    def config_class
      WorkerConfig
    end

    def instance_run

      # NOTE: Here we pull a rubyism ... replace watForJob with the correct method
      #       based on configuration. This way, when we're in the middle of handling
      #       jobs, we don't have to check this value each time.
      case ( @config[ 'queue_method' ] )
      when 'signals' then
        alias :waitForJob :wait_for_job_via_signalling
      when 'polling' then
        alias :waitForJob :wait_for_job_via_polling
      end

      @j = JobStore.instance

      loop do

        begin

          job = next_ready_job
          job.handle_lifecycle unless job.nil?

        rescue => e

          # Show the error on stderr.
          display_error_message( e.message )
          display_error_message( e.backtrace )

          if $DEBUG
            require 'pry'
            binding.pry
          end

          # In the event we had an error, we disconnect & reconnect to redis.
          @j.disconnect
          @j = JobStore.instance

          retry

        end

      end

    end

  end

end
