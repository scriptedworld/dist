#!/usr/bin/env ruby

require 'sinatra'
require 'redis'
require 'json'
require 'yaml'

require 'singleton'

require 'gruff'

this_dir = File.dirname( __FILE__ )
$LOAD_PATH << this_dir unless $LOAD_PATH.include? this_dir
lib_dir = File.join( this_dir, 'lib' )
$LOAD_PATH << lib_dir unless $LOAD_PATH.include? lib_dir

require 'helpers'
require 'config/dataconfig'
require 'graph'

class DataService

  include Singleton

  def initialize()

    assert_not_nil( @@config )

    @config = @@config
    connect
  end

  def self.config=( config )
    @@config = config
    instance.reconnect
  end

  def connect
    @redis = Redis.new( host: @config[ 'redis_host' ], port: @config[ 'redis_port' ], client: :hiredis )
    @redis.auth( @config[ 'redis_pass' ] )
  end

  def disconnect
    @redis.quit unless @redis.nil?
  end

  def reconnect
    disconnect
    connect
  end

  def getTimestamps
    @redis.smembers( 'metrics_timestamps' ).sort
  end

  # Take the tree and combine nodes that have only one child.
  def combine_trie_single_child_nodes( trie )

    # Pull keys snapshot to iterate while modifying the hash members.
    keys = trie.keys

    keys.each do |curr_key|
      curr_value = trie[ curr_key ]

      # Depth first.
      combine_trie_single_child_nodes( curr_value )

      # Finally combine single children into the parent.
      if curr_value.size == 1
        trie[ curr_key + curr_value.keys.first ] = curr_value.values.first
        trie.delete( curr_key )
      end
    end
  end

  # This function returns the new data set
  # ( since we can't replace a parent reference from within. )
  def convert_string_hashes_to_arrays( trie )
    return trie unless trie.is_a?( Hash )

    # Iterate elements looking for non-string children.
    if( trie.values.all? { |curr_value| curr_value.is_a?( String ) } )
      return trie.keys
    else
      keys_to_non_strings = trie.keys.reject { |curr_key| trie[ curr_key ].is_a?( String ) }
      keys_to_non_strings.each do |curr_key| 
        curr_child = trie[ curr_key ]
        curr_child = convert_string_hashes_to_arrays( curr_child )
        trie[ curr_key ] = curr_child
      end
      return trie
    end
  end

  # Take the tree ... and convert empty hashes into strings.
  def convert_trie_empty_nodes( trie )
    trie.each_pair do |curr_key, curr_value|
      if curr_value.empty?
        trie[ curr_key ] = curr_key
      else
        convert_trie_empty_nodes( curr_value )
      end
    end
  end

  def expand_names( trie, common='', full_expand=false )

    case trie
      when Array
        trie.each_with_index { |e, i| trie[i] =  [ e, ( common + e ) ] }
      when Hash
        keys = trie.keys
        keys.each do |curr_key| 
          expand_names( trie[ curr_key ], ( common + curr_key ), full_expand )
          if( full_expand )
            trie[ ( common + curr_key ) ] = trie.delete( curr_key )
          end
        end
      else
        # Do nothing.
    end

  end

  def build_name_tree( tree )

    # Build collection of name segments pername.
    name_segments = tree.collect { |item| item.scan( /[^_:.]+[_:.]?/ ) }

    # Collect segments into Hierarchy based on common prefixes.
    name_trie = Hash.new
    last_segment = nil

    name_segments.each do |item|
      item.each_with_index do |segment, index|
        last_segment = name_trie if index == 0

        unless( last_segment.key? segment )
          last_segment[ segment ] = Hash.new
        end

        last_segment = last_segment[ segment ]
      end
    end

    # Now clean up ... First, single_children nodes should be combined into the parent.
    combine_trie_single_child_nodes( name_trie )

    # Next convert nodes with no children into strings.
    convert_trie_empty_nodes( name_trie )

    # Finally convert node where all children are strings into arrays.
    convert_string_hashes_to_arrays( name_trie )

    # Finally expand the names so short name maps to it's full name.
    expand_names( name_trie )

    name_trie

  end

  def getNames
    name_collection = Array.new
    @redis.smembers( 'metrics_names' ).sort.each do |curr_name|
      if( curr_name.start_with?( 'elapsed_' ) )
        STANDARD_NAMES.each { |name| name_collection << "#{ curr_name }:#{ name }" }
        PERCENTILE_NAMES.each { |name| name_collection << "#{ curr_name }:#{ name }" }
      else
        name_collection << curr_name
      end
    end

    name_collection

  end

  def buildResponse( status, data, content_type, headers={} )
    headers[ 'Content-Type' ] = content_type
    [ status, headers, data ]
  end

  def buildJSONResponse( data )
    buildResponse( 200, data.to_json, 'application/json' )
  end

  def buildPNGResponse( data )
    buildResponse( 200, data, 'image/png' )
  end

  def buildGraph( data )

    graph_options                    = Hash.new
    graph_options[:background_image] = @config[ 'graph_background_image' ]
    graph_options[:index_format]     = @config[ 'graph_index_format' ]

    g = Graph.new( graph_options )

    buildPNGResponse( g.run( data ) )
  end

  # This method will generate a collection of values against the stats ...
  def buildMetricBreakdown( data )
    output = Hash.new

    # For each collection of values in data.
    data.each_pair do |curr_key, curr_values|
      output[ curr_key ] = calcFieldStats( curr_values )
    end

    output
  end

  def getData( query, from=nil, to=nil )

    output = Hash.new
    timestamp_output = Array.new

    timestamps = getTimestamps()
    known_names = getNames()

    from = timestamps.min if from.nil?
    from = Float( from )

    to = timestamps.max if to.nil?
    to = Float( to )

    timestamps = timestamps.select do |t| 
      comp = Float( t )

      ( comp >= from ) and ( comp <= to )
    end

    metric_names = query.split( /,/ ).select { |curr_name| known_names.include?( curr_name ) }
    metric_names.each { |curr_name| output[ curr_name ] = Array.new }

    timestamps.each do |curr_timestamp|

      curr_metric = @redis.get( "metrics.#{ curr_timestamp }" )
      metric_object = YAML.load( curr_metric )

      metric_names.each do |curr_name|

        current_object = metric_object[ curr_name ]

        if( curr_name.start_with?( 'elapsed_' ) )

          parts = curr_name.split( ':', 2 )
          metric_name = parts[0]
          stat = parts[1]

          current_object = metric_object[ metric_name ]

          current_object = nil if stat.nil?

          stat = stat.to_sym

          current_object = current_object[ stat ] unless current_object.nil?

        end

        output[ curr_name ] << current_object

      end

      timestamp_output << ( Float( curr_timestamp ) * 1000 ).to_i

    end

    output[ 'timestamps' ] = timestamp_output

    output
  end

  def buildNamesFlatResponse
    buildJSONResponse( getNames() )
  end

  def buildNamesHierResponse
    buildJSONResponse( build_name_tree( getNames() ) )
  end

  def buildTimestampsResponse
    buildJSONResponse( getTimestamps() )
  end

  def buildQueryResponse( query, from=nil, to=nil )
    buildJSONResponse( getData( query, from, to ) )
  end

  def buildGraphResponse( query, from=nil, to=nil )
    buildGraph( getData( query, from, to ) )
  end

  def buildStatsResponse( query, from=nil, to=nil )
    buildMetricBreakdown( getData( query, from, to ) )
  end

end

# Set the public directory for serving up the page to show graphs in JS.
set :public_folder, File.dirname(__FILE__) + '/graph'

## NOTE: We don't bind or set port any more as Unicorn takes care of this for us.
# set :bind, $config[ 'web_address' ]
# set :port, $config[ 'web_port' ]

get '/' do
  redirect '/index.html'
end

get '/names' do
  redirect '/names/flat'
end

get '/names/flat' do
  DataService.instance.buildNamesFlatResponse
end

get '/names/hier' do
  DataService.instance.buildNamesHierResponse
end

get '/timestamps' do
  DataService.instance.buildTimestampsResponse
end

# Return all values matching the query
get '/data/:query/all' do |query|
  DataService.instance.buildQueryResponse( query )
end

# Return a window values matching the query
get '/data/:query/:from/:to' do |query, from, to|
  DataService.instance.buildQueryResponse( query, from, to )
end

get '/graph/:query/all' do |query|
  DataService.instance.buildGraphResponse( query )
end

get '/graph/:query/:from/:to' do |query, from, to|
  DataService.instance.buildGraphResponse( query, from, to )
end

get '/stats/:query/all' do |query|
  DataService.instance.buildStatsResponse( query )
end

get '/stats/:query/:from/:to' do |query, from, to|
  DataService.instance.buildStatsResponse( query, from, to )
end


