
require './lib/helpers.rb'

class Job

  def initialize( id = nil )
    @job_store                 = JobStore.new

    @phase_stack               = Array.new
    @phase_delimiter           = '.'

    @timing_stats_prefix       = 'stats.timing.'
    @timing_stats_start_suffix = 'begin'
    @timing_stats_end_suffix   = 'end'

    @failure_error_message_key = 'failure.error.message'
    @failure_error_trace_key   = 'failure.error.stacktrace'

    # If id was nil, one will be assigned when the job is saved.
    @job_id                    = id
    @job_data                  = Hash.new
    @job_state                 = 'INITIAL'

    load

  end

  def []( key )
    @job_data[ key ]
  end

  def []=( key, value )
    @job_data[ key ] = value
  end

  def setAttributes( replacement_hash )
    @job_data = replacement_hash
  end

  def setItemID( new_id )
    displayDebugMessage( "Overwritting existing Item ID for #{ @job_id } to #{ new_id }." ) unless @job_id.nil?
    @job_id = new_id
  end

  def load
    unless( @job_id.nil? )
      @job_data = @job_store.loadItem( @job_id )

      # Add holders for failure information if they don't exist.
      @job_data[@failure_error_message_key] ||= Array.new
      @job_data[@failure_error_trace_key] ||= Array.new
    end

    displayDebugMessage( { id: @job_id, attributes: @job_data } ) unless @job_id.nil?
  end

  # When we go to save a job, we will assign an ID if previously nil.
  def save
    if( @job_id.nil? )
      @job_id = @job_store.getNewItemID()
    end
    @job_store.saveItem( @job_id, @job_data )

    displayDebugMessage( { id: @job_id, attributes: @job_data } )
  end

  def signalReady
    @job_store.publishItemReadySignal()
  end

  def start
    setState( 'PROCESSING' )
  end

  def setup
    # pass. to be overridden by derivative class.
  end

  def run
    # to be overridden by derivative class.
    raise "Job::run must be overridden."
  end

  def teardown( e = nil )
    # pass. to be overridden by derivative class.
  end

  def success
    setState( 'COMPLETE' )
  end

  def failure( e = nil )
    setState( 'BROKEN' )
  end

  def getState
    @job_store.getItemState( @job_id )
  end

  # WARNING: Setting state does not update the JobStore automatically>
  def setState( new_state )
    @job_store.setItemState( @job_id, new_state )
  end

  def recordException( e )
    @job_data[ @failure_error_message_key ] = Array.new unless @job_data.key?( @failure_error_message_key )
    @job_data[ @failure_error_trace_key ] = Array.new unless @job_data.key?( @failure_error_trace_key )
    @job_data[ @failure_error_message_key ] << e.message
    @job_data[ @failure_error_trace_key ] << e.backtrace
  end

  def handleLifecycle
    startPhase( 'lifecycle' )

    begin

      doPhase( 'start' ) do
        start()
      end

      doPhase( 'setup' ) do
        setup()
      end

      doPhase( 'run' ) do
        run()
      end

      doPhase( 'teardown' ) do
        teardown()
      end

      doPhase( 'success' ) do
        success()
      end

    rescue JobException => e
      # Recoverable error.
      doPhase( 'failure_teardown' ) do
        teardown( e )
      end

      recordException( e )
      setState( 'READY' )
    rescue Exception => e
      # Unrecoverable error.
      doPhase( 'failure_teardown' ) do
        teardown( e )
      end

      recordException( e )

      doPhase( 'failure' ) do
        failure( e )
      end

    ensure
      endPhase( 'lifecycle' )

      save()
    end

  end

  def doPhase( phase_name, &block )
    startPhase( phase_name )
    yield 
    endPhase( phase_name )
  end

  def startPhase( phase_name )
    @phase_stack << phase_name
    trackTimestamp( @timing_stats_start_suffix )
  end

  def endPhase( phase_name )
    raise "Phase #{ phase_name } not found." unless( @phase_stack.include?( phase_name ) )

    found = false
    while( found == false ) do
      trackTimestamp( @timing_stats_end_suffix )
      curr = @phase_stack.pop
      found = ( curr == phase_name )
    end
  end

  def getPhaseTag
    @phase_stack.join( @phase_delimiter )
  end

  def trackTimestamp( name )
    complete_name = @timing_stats_prefix + getPhaseTag + @phase_delimiter + name
    displayDebugMessage( "Warning: Overwritting #{ complete_name }" ) if @job_data.key?( complete_name )
    @job_data[ complete_name ] = Time.now.to_f
  end

end

