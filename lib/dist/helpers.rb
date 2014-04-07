require 'logger'
require 'net/http'

require 'awesome_print'
require 'json'
require 'yaml'

require 'dist/assert'

require 'dist/store/jobstore'
require 'dist/store/eventstore'

require 'dist/job/job'
require 'dist/job/jobexception'

# NOTE: Events do not require classes,
#       they are simply freeform data. Jobs have extended functionality.

# The following Job subtypes are testing specific, and have no other purpose.
require 'dist/job/emptyjob'
require 'dist/job/exceptionjob'
require 'dist/job/jobexceptionjob'

module Dist

  module Helpers

    include Asserts

    # This stores the number of milliseconds in 1 interval of the given length
    TIME_UNITS = { 'MILLIS' => 1,                # 1 ms is 1 ms
                   'SECOND' => 1_000,            # 1000 ms in 1 sec
                   'MINUTE' => 60_000,           # 60 sec in 1 min
                   'HOUR'   => 3_600_000,        # 60 min in 1 hr
                   'DAY'    => 86_400_000,       # 24 hr in 1 day
                   'WEEK'   => 604_800_000 }     # 7 days in 1 wk

    # Predefined sets of chars for the random-char and random-string functions.
    ALPHA_CHARS        = %w( A B C D E F G H I J K L M N O P Q R S T U V W X Y Z )
    NUMERIC_CHARS      = %w( 0 1 2 3 4 5 6 7 8 9 )
    ALPHANUMERIC_CHARS = ALPHA_CHARS + NUMERIC_CHARS
    HEXALPHA_CHARS     = %w( A B C D E F )
    HEX_CHARS          = HEXALPHA_CHARS + NUMERIC_CHARS

    STANDARD_NAMES     = %w( count min max sum mean stdev )
    PERCENTILE_VALUES  = [ 10, 20, 30, 40, 50, 60, 70, 80, 90, 95, 98, 99 ]
    PERCENTILE_NAMES   = PERCENTILE_VALUES.map { |i| "tp#{ i }" }

    def handle_redis_config( redis_host, redis_port, redis_pass )
      display_debug_message( "Update redis config: #{ redis_host } #{ redis_port } #{ redis_pass }" )
      ObjectStore.redis_host = redis_host
      ObjectStore.redis_port = redis_port
      ObjectStore.redis_pass = redis_pass
    end

    def load_file( file_path )
      raise "File '#{ file_path }' not found." unless File.exist?( file_path )
      File.open( file_path ).read
    end

    def load_json_file( file_path )
      JSON.parse( load_file( file_path ) )
    end

    def load_yaml_file( file_path )
      YAML.load( load_file( file_path ) )
    end

    def class_exists?( class_name )
      klass = Module.const_get( class_name )
      klass.is_a?( Class )
    rescue NameError
      false
    end

    def validate_keys_exist( hash, *attribute_names )
      raise 'Provided argument is nil.' if hash.nil?
      raise 'Provided argument is not a hash.' unless hash.kind_of?( Hash )

      attribute_names.each do |a|
        raise "Key #{ a } missing." unless hash.key?( a )
      end
    end

    def validate_time_interval_name( name )
      raise "Unacceptable time interval name #{ name } provided." unless TIME_UNITS.keys.include?( name )
    end

    def get_random_char( acceptable_chars )
      acceptable_chars.shuffle.first
    end

    def get_random_string( acceptable_chars, length )
      output = ''
      length.times { output << get_random_char( acceptable_chars ) }
      output
    end

    # Internal function used by get_normalized_random_number
    def rnd_snd
      ( ( ( Kernel.rand * 2.0 ) - 1.0 ) +
       ( ( Kernel.rand * 2.0 ) - 1.0 ) +
       ( ( Kernel.rand * 2.0 ) - 1.0 ) )
    end

    def get_normalized_random_number( mean, stdev )
      ( ( rnd_snd.to_f * stdev.to_f ) + mean.to_f )
    end

    def wait_seconds( duration, absolute = false, stdev = nil )
      real_duration = 0

      if absolute
        real_duration = duration
      else
        # IF the stdev was not provided, calculate something that will be relatively stable.
        stdev = duration.to_f / 4.to_f if stdev.nil?
        real_duration = get_normalized_random_number( duration, stdev )
      end

      display_debug_message "Sleeping for #{ real_duration } seconds."
      sleep( real_duration )
    end

    # This function is used by getRegexMatch to collect the collections of matches for each line of the given input
    def collect_regex_matches( input, regex )
      matches = []
      input.lines.each do |line|
        m = regex.match( line )
        matches << m unless m.nil? == true
      end
      matches
    end

    # Collect all of the matches, assert against an expected count, and then yield the collection of matches for further processing.
    def get_regex_matches( content, regex, expected_match_count = 1 )
      matches = collect_regex_matches( content, regex )
      assert( matches.length == expected_match_count, "REGEX match not found expected count of times: #{ expected_match_count }." )
      yield matches if block_given?
    end

    ## Statistic functions.
    # Handle simple statistics.
    def get_base_stats( hash, inputArray )

      if ( inputArray.nil? == false ) && ( inputArray.empty? == false )
        inputArray.sort!
        hash[ 'count' ] = inputArray.size
        hash[ 'min' ]   = inputArray.min
        hash[ 'max' ]   = inputArray.max
        hash[ 'sum' ]   = inputArray.reduce(0) { |a, e| a + e }
        hash[ 'mean' ]  = hash[ 'sum' ] / hash[ 'count' ]
      else
        hash[ 'count' ] = 0
        hash[ 'min' ]   = 0
        hash[ 'max' ]   = 0
        hash[ 'sum' ]   = 0
        hash[ 'mean' ]  = 0
      end

    end

    # Handle StdDev calc.
    def get_stddev( hash, inputArray )

      if ( inputArray.nil? == false ) && ( inputArray.empty? == false )

        # Collect the deviations ( meaning the distance from the mean for each value ... and square them.
        deviations = inputArray.map { |item| ( item - hash[ 'mean' ] )**2 }
        # Sum the deviations
        deviation_sum = deviations.reduce( 0 ) { |a, e| a + e }
        # Finally take the squareroot after dividing by 1 less than the count of values in the collection.
        hash[ 'stddev' ] = ( ( deviation_sum / ( hash[ 'count' ] - 1 ) )**0.5 )

      else

        hash[ 'stddev' ] = 0

      end

    end

    # NOTE: This method assumes the array passed as input has already been sorted.
    # NOTE: This method assumes percentile will be a floating point value between 0 - 100.0
    def get_percentile( percentile, input )

      output = 0

      if ( input.nil? == false ) && ( input.empty? == false )

        percentile_element = 0

        if percentile != 0
          percentile_element = ( ( ( input.size ).to_f * ( percentile.to_f / 100.0 ) ).ceil - 1 )
        end

        output = input[ percentile_element ]

      end

      output

    end

    # Create a hash including all of the std & requested stats for the given input array ( Expects Numberic values ).
    def calc_field_stats( inputArray )

      field_stats = {}

      get_base_stats( field_stats, inputArray )
      get_stddev( field_stats, inputArray )

      # Now get all of the user requested TP stats.
      PERCENTILE_VALUES.each_with_index do |curr_tp, index|
        field_stats[ PERCENTILE_NAMES[ index ] ] = get_percentile( curr_tp, inputArray )
      end

      # return calculated stats.
      field_stats

    end

    def record_run_event( event_name, additional_data = {} )
      event_store = EventStore.instance

      new_id = event_store.next_item_id

      attributes = {}
      attributes.merge!( additional_data )
      attributes[ 'name' ] = event_name
      attributes[ 'timestamp' ] = Time.now.to_f

      event_store.save_item( new_id, attributes )
    end

  end

end
