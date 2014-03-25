
require 'sinatra'

require 'dist/data/service'

module Dist

  class DataServer < Sinatra::Base
    # TODO: The following file path will have to handle this code being Gemified.

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

  end

end

