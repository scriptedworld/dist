
require 'dist/helpers'
require 'dist/logged'

module Dist

  class Job

    # include Helpers
    include Logged

    def initialize( id = nil )
      @job_store                 = JobStore.new

      @phase_stack               = []
      @phase_delimiter           = '.'

      @timing_stats_prefix       = 'stats.timing.'
      @timing_stats_start_suffix = 'begin'
      @timing_stats_end_suffix   = 'end'

      @failure_error_message_key = 'failure.error.message'
      @failure_error_trace_key   = 'failure.error.stacktrace'

      # If id was nil, one will be assigned when the job is saved.
      @job_id                    = id
      @job_data                  = {}
      @job_state                 = 'INITIAL'

      load

    end

    def []( key )
      @job_data[ key ]
    end

    def []=( key, value )
      @job_data[ key ] = value
    end

    def set_attributes( replacement_hash )
      @job_data = replacement_hash
    end

    def set_item_id( new_id )
      display_debug_message( "Overwritting existing Item ID for #{ @job_id } to #{ new_id }." ) unless @job_id.nil?
      @job_id = new_id
    end

    def load
      unless @job_id.nil?
        @job_data = @job_store.load_item( @job_id )

        # Add holders for failure information if they don't exist.
        @job_data[ @failure_error_message_key ] ||= []
        @job_data[ @failure_error_trace_key   ] ||= []
      end

      display_debug_message( id: @job_id, attributes: @job_data ) unless @job_id.nil?
    end

    # When we go to save a job, we will assign an ID if previously nil.
    def save
      @job_id = @job_store.get_new_item_id if @job_id.nil?

      @job_store.save_item( @job_id, @job_data )

      display_debug_message( id: @job_id, attributes: @job_data )
    end

    def signal_ready
      @job_store.publish_item_ready_signal
    end

    def start
      set_state( 'PROCESSING' )
    end

    def setup
      # pass. to be overridden by derivative class.
    end

    def run
      # to be overridden by derivative class.
      raise 'Job::run must be overridden.'
    end

    def teardown( e = nil )
      # pass. to be overridden by derivative class.
    end

    def success
      set_state( 'COMPLETE' )
    end

    def failure( e = nil )
      set_state( 'BROKEN' )
    end

    def get_state
      @job_store.get_item_state( @job_id )
    end

    # WARNING: Setting state does not update the JobStore automatically>
    def set_state( new_state )
      @job_store.set_item_state( @job_id, new_state )
    end

    def record_exception( e )
      @job_data[ @failure_error_message_key ] = [] unless @job_data.key?( @failure_error_message_key )
      @job_data[ @failure_error_trace_key   ] = [] unless @job_data.key?( @failure_error_trace_key )
      @job_data[ @failure_error_message_key ] << e.message
      @job_data[ @failure_error_trace_key   ] << e.backtrace
    end

    def handle_lifecycle
      start_phase( 'lifecycle' )

      begin

        do_phase( 'start' ) do
          start
        end

        do_phase( 'setup' ) do
          setup
        end

        do_phase( 'run' ) do
          run
        end

        do_phase( 'teardown' ) do
          teardown
        end

        do_phase( 'success' ) do
          success
        end

      rescue JobException => e
        # Recoverable error.
        do_phase( 'failure_teardown' ) do
          teardown( e )
        end

        record_exception( e )
        set_state( 'READY' )
      rescue Exception => e
        # Unrecoverable error.
        do_phase( 'failure_teardown' ) do
          teardown( e )
        end

        record_exception( e )

        do_phase( 'failure' ) do
          failure( e )
        end

      ensure
        end_phase( 'lifecycle' )

        save
      end

    end

    def do_phase( phase_name, &block )
      start_phase( phase_name )
      yield
      end_phase( phase_name )
    end

    def start_phase( phase_name )
      @phase_stack << phase_name
      track_timestamp( @timing_stats_start_suffix )
    end

    def end_phase( phase_name )
      raise "Phase #{ phase_name } not found." unless @phase_stack.include?( phase_name )

      found = false
      while found == false
        track_timestamp( @timing_stats_end_suffix )
        curr = @phase_stack.pop
        found = ( curr == phase_name )
      end
    end

    def get_phase_tag
      @phase_stack.join( @phase_delimiter )
    end

    def track_timestamp( name )
      complete_name = @timing_stats_prefix + get_phase_tag + @phase_delimiter + name
      display_debug_message( "Warning: Overwritting #{ complete_name }" ) if @job_data.key?( complete_name )
      @job_data[ complete_name ] = Time.now.to_f
    end

  end

end
