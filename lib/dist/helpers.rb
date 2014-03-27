
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
    TIME_UNITS = { 'MILLIS' => 1,              # 1 ms is 1 ms
                   'SECOND' => 1000,           # 1000 ms in 1 sec
                   'MINUTE' => 60000,          # 60 sec in 1 min
                   'HOUR'   => 3600000,        # 60 min in 1 hr
                   'DAY'    => 86400000,       # 24 hr in 1 day
                   'WEEK'   => 604800000 }     # 7 days in 1 wk

    # Predefined sets of chars for the random-char and random-string functions.
    ALPHA_CHARS        = %w( A B C D E F G H I J K L M N O P Q R S T U V W X Y Z )
    NUMERIC_CHARS      = %w( 0 1 2 3 4 5 6 7 8 9 )
    ALPHANUMERIC_CHARS = ALPHA_CHARS + NUMERIC_CHARS
    HEXALPHA_CHARS     = %w( A B C D E F )
    HEX_CHARS          = HEXALPHA_CHARS + NUMERIC_CHARS

    STANDARD_NAMES     = %w( count min max sum mean stdev )
    PERCENTILE_VALUES  = [ 10, 20, 30, 40, 50, 60, 70, 80, 90, 95, 98, 99 ]
    PERCENTILE_NAMES   = PERCENTILE_VALUES.collect { |i| "tp#{ i }" }

    def handleRedisConfig( redis_host, redis_port, redis_pass )
      $host = redis_host
      $port = redis_port
      $pass = redis_pass
    end

    def loadFile( file_path )
      raise "File '#{ file_path }' not found." unless File.exists?( file_path )
      File.open( file_path ).read()
    end

    def loadJSONFile( file_path )
      JSON.parse( loadFile( file_path ) )
    end

    def loadYAMLFile( file_path )
      YAML.load( loadFile( file_path ) )
    end

    def class_exists?( class_name )
      klass = Module.const_get( class_name )
      klass.is_a?( Class )
    rescue NameError
      false
    end

    def validateKeysExist( hash, *attribute_names )
      raise "Provided argument is nil." if hash.nil?
      raise "Provided argument is not a hash." unless hash.kind_of?( Hash )

      attribute_names.each do |a|
        raise "Key #{ a } missing." unless hash.key?( a )
      end
    end

    def validateTimeIntervalName( name )
      raise "Unacceptable time interval name #{ name } provided." unless TIME_UNITS.keys.include?( name )
    end

    def getRandomChar( acceptable_chars )
      acceptable_chars.shuffle.first
    end

    def getRandomString( acceptable_chars, length )
      output = ""
      length.times { output << getRandomChar( acceptable_chars ) }
      output
    end

    # Internal function used by getNormalizedRandomNumber
    def rnd_snd
      ( ( ( Kernel.rand * 2.0 ) - 1.0 ) +
        ( ( Kernel.rand * 2.0 ) - 1.0 ) +
        ( ( Kernel.rand * 2.0 ) - 1.0 ) )
    end

    def getNormalizedRandomNumber( mean, stdev )
      ( ( rnd_snd.to_f * stdev.to_f ) + mean.to_f )
    end

    def waitSeconds( duration, absolute=false, stdev=nil )
      real_duration = 0

      if( absolute )
        real_duration = duration
      else
        # IF the stdev was not provided, calculate something that will be relatively stable.
        stdev = duration.to_f / 4.to_f if stdev.nil?
        real_duration = getNormalizedRandomNumber( duration, stdev )
      end

      displayDebugMessage "Sleeping for #{ real_duration } seconds."
      sleep( real_duration )
    end

    # This function is used by getRegexMatch to collect the collections of matches for each line of the given input
    def collectRegexMatches( input, regex )
      matches = []
      input.lines.each do |line|
        m = regex.match( line )
        matches << m unless m.nil? == true
      end
      matches
    end

    # Collect all of the matches, assert against an expected count, and then yield the collection of matches for further processing.
    def getRegexMatches( content, regex, expected_match_count=1 )
      matches = collectRegexMatches( content, regex )
      assert( matches.length == expected_match_count, "REGEX match not found expected count of times: #{ expected_match_count }." )
      yield matches if block_given?
    end

    ## Statistic functions.
    # Handle simple statistics.
    def getBaseStats( hash, inputArray )

      if( ( inputArray.nil? == false ) and ( inputArray.empty? == false ) )
        inputArray.sort!
        hash[ 'count' ] = inputArray.size
        hash[ 'min' ]   = inputArray.min
        hash[ 'max' ]   = inputArray.max
        hash[ 'sum' ]   = inputArray.inject(0) { |sum,value| sum + value }
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
    def getStdDev( hash, inputArray )

      if( ( inputArray.nil? == false ) and ( inputArray.empty? == false ) )

        # Collect the deviations ( meaning the distance from the mean for each value ... and square them.
        deviations = inputArray.collect { |item| ( item - hash[ 'mean' ] ) ** 2 }
        # Sum the deviations
        deviation_sum = deviations.inject( 0 ) { |sum,value| sum + value }
        # Finally take the squareroot after dividing by 1 less than the count of values in the collection.
        hash[ 'stddev' ] = ( deviation_sum / ( hash[ 'count' ] - 1 ) ) ** 0.5

      else

        hash[ 'stddev' ] = 0

      end

    end

    # NOTE: This method assumes the array passed as input has already been sorted.
    # NOTE: This method assumes percentile will be a floating point value between 0 - 100.0
    def getPercentile( percentile, input )

      output = 0

      if( ( input.nil? == false ) and ( input.empty? == false ) )

        percentile_element = 0

        if( percentile != 0 )
          percentile_element = ( ( ( input.size ).to_f * ( percentile.to_f / 100.0 ) ).ceil - 1 )
        end

        output = input[ percentile_element ]

      end

      output

    end

    # Create a hash including all of the std & requested stats for the given input array ( Expects Numberic values ).
    def calcFieldStats( inputArray )

      tmp = Hash.new

      getBaseStats( tmp, inputArray )
      getStdDev( tmp, inputArray )

      # Now get all of the user requested TP stats.
      PERCENTILE_VALUES.each_with_index do |curr_tp, index|
        tmp[ PERCENTILE_NAMES[ index ] ] = getPercentile( curr_tp, inputArray )
      end

      return tmp

    end

  end

end
