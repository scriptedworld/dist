#!/usr/bin/env ruby

require './lib/helpers.rb'
require './lib/config/reporterconfig.rb'

class StatsContainer

  def initialize
    @host  = nil
    @port  = nil
    @pass  = nil
    @redis = nil
    @stats = Hash.new
  end

  def configureRedis( host, port, pass )
    @host  = host
    @port  = port
    @pass  = pass
    @redis = Redis.new( host: @host, port: @port, driver: :hiredis )
    @redis.auth( @pass )
  end

  def setTimestamp( timestamp )
    @stats[ 'timestamp' ] = timestamp
  end

  def getSystemwideStats
    raise "Not connected to Redis." if @redis.nil?

    @stats[ 'redis_transaction_count' ]    = @redis.info()['total_commands_processed'].to_i
    @stats[ 'redis_keyset_count' ]         = @redis.dbsize()

    @stats[ 'jobs_ready_count' ]           = @redis.scard( 'jobs.READY' )
    @stats[ 'jobs_processing_count' ]      = @redis.scard( 'jobs.PROCESSING' )
    @stats[ 'jobs_complete_count' ]        = @redis.scard( 'jobs.COMPLETE' )
    @stats[ 'jobs_broken_count' ]          = @redis.scard( 'jobs.BROKEN' )

    @stats[ 'devices_unregistered_count' ] = @redis.scard( 'devices.UNREGISTERED' )
    @stats[ 'devices_unsubscribed_count' ] = @redis.scard( 'devices.UNSUBSCRIBED' )
    @stats[ 'devices_freetrial_count' ]    = @redis.scard( 'devices.FREETRIAL' )
    @stats[ 'devices_subscribed_count' ]   = @redis.scard( 'devices.SUBSCRIBED' )
    @stats[ 'devices_locked_count' ]       = @redis.scard( 'devices.LOCKED' )
    @stats[ 'devices_broken_count' ]       = @redis.scard( 'devices.BROKEN' )

    # TODO: Add code here to track the number of idle workers 
    #       ( through the count of subscribers for the job ready channel )
  end

  def setupQueueForReview( job_state )

    @review_set_name = "stats_work.REVIEW_#{ job_state }"
    @lifecycle_set_name = "jobs.#{ job_state }"
    @seen_set_name = "stats_work.SEEN_#{ job_state }"

    @redis.sdiffstore( @review_set_name, @lifecycle_set_name, @seen_set_name )

    if( $DEBUG )
      jobs_in_state_count = @redis.scard( @lifecycle_set_name )
      review_count        = @redis.scard( @review_set_name )
      seen_count          = @redis.scard( @seen_set_name )

      displayDebugMessage( "Total Quantity: #{ jobs_in_state_count }" )
      displayDebugMessage( "Quantity to review: #{ review_count }" )
      displayDebugMessage( "Quantity already seen: #{ seen_count }" )
    end

  end

  def getElapsedTimesForJob( job_data )

    timing_stat_prefix = 'stats.timing.lifecycle.'
    timing_stat_suffix_begin = '.begin'
    timing_stat_suffix_end   = '.end'

    elapsed_times = Hash.new

    job_data.keys.grep( /^#{ timing_stat_prefix }/ ).each do |curr_stat_name|

      if( curr_stat_name.end_with?( timing_stat_suffix_begin ) )
        phase_name = curr_stat_name[ timing_stat_prefix.length .. -( timing_stat_suffix_begin.length + 1 ) ]

        phase_start_time = job_data[ curr_stat_name ]
        phase_end_time   = job_data[ curr_stat_name[ 0 .. -( timing_stat_suffix_begin.length + 1 ) ] + timing_stat_suffix_end ]
        phase_elapsed    = phase_end_time - phase_start_time

        phase_name = 'lifecycle' if phase_name == ''

        elapsed_times[ phase_name ] = phase_elapsed
      end

    end

    elapsed_times

  end

  def calcStatsForJobState( job_state )
    raise "Not connected to Redis." if @redis.nil?

    displayDebugMessage( "Calcing for #{ job_state }" )

    # This MUST be called, it sets variables used later in this function.
    setupQueueForReview( job_state )

    all_lifecycle_durations = Array.new
    duration_values = Hash.new { |hash, key| hash[ key ] = Array.new }

    job_class_counts = Hash.new( 0 )

    curr_job_id = @redis.spop( @review_set_name )
    while( curr_job_id.nil? == false ) do

      displayDebugMessage( "Processing stats for #{ curr_job_id }" )

      job_data = YAML.load( @redis.get( curr_job_id ) )
      job_class = job_data[ 'job_class' ]

      elapsed_values = getElapsedTimesForJob( job_data )

      elapsed_values.each_pair do |key, value|
        if( key == 'lifecycle' )
          all_lifecycle_durations << value
        end

        duration_values[ "#{ job_class }.#{ key }" ] << value
      end

      job_class_counts[ job_class ] += 1

      # Clean up, finish up with the current job
      @redis.sadd( @seen_set_name, curr_job_id )

      # Get another.
      curr_job_id = @redis.spop( @review_set_name )
    end

    duration_values.each_pair do |key, value|
      metrics = calcFieldStats( value )
      @stats[ "elapsed_#{ job_state }_#{ key }" ] = metrics
    end

    metrics = calcFieldStats( all_lifecycle_durations )
    @stats[ "elapsed_#{ job_state }_all" ] = metrics 

    # We should track how many jobs of each class occurred in this state.
    job_class_counts.each_pair do |key, value|
      @stats[ "#{ job_state }_#{ job_class }_count" ] = value
    end

  end

  def calcDiffs
    raise "Not connected to Redis." if @redis.nil?

    @stats.keys.grep( /.+_count$/ ).each do |count_field|

      last_field_name = "last_#{ count_field }"

      last_value = @redis.get( last_field_name )
      last_value = ( last_value.nil? ) ? 0 : Integer( last_value )

      delta = @stats[ count_field ] - last_value

      @stats[ "#{ count_field }_delta" ] = delta

      @redis.set( last_field_name, @stats[ count_field ] )

    end

  end

  def save
    raise "Not connected to Redis." if @redis.nil?

    displayDebugMessage( @stats )

    @redis.set( "metrics.#{ @stats[ 'timestamp' ] }", @stats.to_yaml )

    # Finally, to make things easier for the grapher, track the timestamps 
    # in a collection.
    @redis.sadd( "metrics_timestamps", @stats[ 'timestamp' ] )

    metric_names = @stats.keys
    @redis.sadd( "metrics_names", metric_names )
  end

  def cleanOldStats
    raise "Not connected to Redis." if @redis.nil?

    delta_keys = @redis.keys( "last*" )
    metric_keys = @redis.keys( "metrics*" )

    @redis.del( delta_keys ) unless ( delta_keys.nil? or delta_keys.empty? )
    @redis.del( metric_keys ) unless ( metric_keys.nil? or metric_keys.empty? )
  end

end

config = ReporterConfig.new( ARGV.pop )

# Set up a flag so that our first iteration cleans out stagnant data.
firstRun = true

while( true ) do

  start_time = Time.now.to_f

  displayDebugMessage( "Processing ... #{ start_time }" )

  s = StatsContainer.new
  s.configureRedis( config[ 'redis_host' ], config[ 'redis_port' ], config[ 'redis_pass' ] )

  # Clean up an stale metrics data in REDIS.
  if( firstRun )
    s.cleanOldStats
    firstRun = false
  end

  s.setTimestamp( start_time )

  s.getSystemwideStats()

  %w( COMPLETE BROKEN ).each do |curr_state|
    s.calcStatsForJobState( curr_state )
  end

  s.calcDiffs()

  s.save()

  work_completed_time = Time.now.to_f - start_time
  sleep_time = config[ 'report_interval_seconds' ] - work_completed_time
  sleep( sleep_time )

end

