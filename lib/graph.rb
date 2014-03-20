#!/usr/bin/env ruby

require 'date'
require 'time'

require 'awesome_print'
require 'gruff'
require 'facets'
require 'json'

require 'logged'
require 'helpers'

class Graph

  include Logged

  def initialize( new_options = {} )

    @options                          = {}
    @options[:default_index_format]   = '%H:%M'
    @options[:background_image]       = nil
    @options[:index_format]           = @options[:default_index_format]

    # TODO: Should attempt to ensure that the passed_in new_options is a Hash.
    @options.merge! new_options

  end

  def run( data )

    displayDebugMessage( "Data:" )
    displayDebugMessage( data )

    # Input includes a timestamps collection
    # + Arrays for each stat requested.

    stats = Hash.new
    indexes = Hash.new

    timestamp_count = data[ 'timestamps' ].length
    index_interval = timestamp_count / 6

    ( data.keys - [ 'timestamps' ] ).each do |curr_stat|
      stats[ curr_stat ] = Array.new

      data[ 'timestamps' ].each_with_index do |curr_ts, index|
        stats[ curr_stat ][ index ] = data[ curr_stat ][ index ] || 0.0

        curr_time = Time.at( ( curr_ts / 1000.0 ).to_f ).strftime( @options[:index_format] )

        _, mod = index.divmod( index_interval )
        if mod == 0
          indexes[ index ] = "#{ curr_time }"
        end

      end

    end

    displayDebugMessage( "Stats:" )
    displayDebugMessage( stats )
    displayDebugMessage( "Indexes:" )
    displayDebugMessage( indexes )

    # Lets make a graph!

    g = Gruff::Line.new

    stats.keys.each do |curr_stat|
      g.data( curr_stat, stats[ curr_stat ] )
    end

    theme_options                     = Hash.new
    theme_options[:colors]            = %w( orange purple green white red )
    theme_options[:marker_color]      = 'white'
    theme_options[:font_color]        = 'white'
    theme_options[:background_image]  = @options[:background_image] unless @options[:background_image].nil?

    g.theme = theme_options
    g.labels = indexes

    # TODO: Eventually I need to add support for reference lines for each 
    #       event recorded during the given time period

    g.marker_count = 4

    # Output.
    g.to_blob( 'PNG' )

  end

end

