
require 'set'
require 'redis'
require 'hiredis'
require 'json'
require 'yaml'

class ObjectStore

  def initialize
    @item_ready_signal = 'signal.object.ready'
    @item_id_key       = 'new.object.number'
    @item_prefix       = 'object.'
    @state_prefix      = 'objects.'
    @allowed_states    = Set.new

    @host              = $host
    @port              = $port
    @pass              = $pass

    @@instance         = nil
  end

  def setHost( new_host )
    @host = new_host
  end

  def getHost
    @host
  end

  def setPort( new_port )
    @port = new_port
  end

  def getPort
    @port
  end

  def setPass( new_pass )
    @pass = new_pass
  end

  def getPass
    @pass
  end

  def getInstance
    if( @@instance.nil? )
      raise "Redis Host unconfigured." if @host.nil?
      raise "Redis Port unconfigured." if @port.nil?
      raise "Redis Pass unconfigured." if @pass.nil?
      @@instance = Redis.new( host: @host, port: @port, driver: :hiredis )
      @@instance.auth( @pass )
    end
    @@instance
  end

  def disconnect
    unless( @@instance.nil? )
      @@instance.close
      @@instance = nil
    end
  end

  def setItemPrefix( new_prefix )
    @item_prefix = new_prefix
  end

  def getItemPrefix
    @item_prefix
  end

  def setStatePrefix( new_state_prefix )
    @state_prefix = new_state_prefix
  end

  def getStatePrefix
    @state_prefix
  end

  def setAllowedStates( *states )
    @allowed_states = Set.new
    states.each { |s| @allowed_states << getProperState( s ) }
  end

  def getAllowedStates
    @allowed_states.to_a
  end

  def getProperID( id )
    prepended = "#{ @item_prefix }#{ id }"
    ( id.to_s.start_with?( @item_prefix ) ) ? id : prepended
  end

  def getProperState( state )
    prepended = "#{ @state_prefix }#{ state }"
    ( state.to_s.start_with?( @state_prefix ) ) ? state : prepended
  end

  def loadItem( id )
    item_id = getProperID( id )
    result = nil

    if( getInstance.exists( item_id ) )
      displayDebugMessage( "Retrieving data for #{ item_id }" )
      result = YAML.load( getInstance.get( item_id ) )
      # result = JSON.parse( getInstance.get( item_id ) )
    else
      # Bad situation. Requested Item didn't exist.
      raise "Item #{ id } -> #{ item_id } not found."
    end
    result
  end

  def saveItem( id, data )
    item_id = getProperID( id )
    displayDebugMessage( "Storing data as #{ id } -> #{ item_id }" )
    getInstance.set( item_id, data.to_yaml )
    # getInstance.set( item_id, data.to_json )
  end

  def checkItemExists( id )
    item_id = getProperID( id )
    getInstance.exists( item_id )
  end

  def getItemState( id )
    item_id = getProperID( id )

    matches = @allowed_states.find_all { |s| getInstance.sismember( getProperState( s ), item_id ) }

    if( matches.length > 0 )
      if( matches.length > 1 )
        # Bad situation. Requested item was found in multiple state collections.
        raise "Found #{ item_id } in #{ matches.to_json }"
      else
        matches = matches[0]
      end
    else
      matches = nil
    end

    matches
  end

  # TODO: Eventually, we may be able to optimize this by providing the state 
  #       we know the id to exist in ( preventing the search )
  def setItemState( id, new_state )

    new_state = getProperState( new_state )

    raise "Attempted to set item #{ id } to invalid state #{ new_state }." unless @allowed_states.include?( new_state )

    item_id = getProperID( id )
    curr_state = getItemState( id )

    curr_state = getProperState( curr_state ) unless curr_state.nil?
    new_state = getProperState( new_state )


    # optimization, no point in a no-op.
    if curr_state == new_state
      return
    end

    if( curr_state.nil? )
      # No prior state.
      displayDebugMessage( "Adding item to state #{ new_state }." )
      getInstance.sadd( new_state, item_id )
    else
      # Existing state.
      displayDebugMessage( "Moving item #{ item_id } to #{ new_state } from #{ curr_state.nil? ? 'nil' : curr_state }." )
      getInstance.smove( curr_state, new_state, item_id ) unless curr_state.nil?
    end

  end

  def getNewItemIDKey
    @item_id_key
  end

  def setNewItemIDKey( new_key )
    @item_id_key = new_key
  end

  def getItemReadySignalName
    @item_ready_signal
  end

  def setItemReadySignalName( new_signal_name )
    @item_ready_signal = new_signal_name
  end

  def setNextNewItemID( new_value )
    new_value = Integer( new_value )
    getInstance.set( @item_id_key, new_value )
  end

  def getNewItemID
    getInstance.incr( @item_id_key )
  end

  def publishSignal( signalname )
    getInstance.publish( signalname, '1' )
  end

  def waitForSignal( signalname )
    getInstance.subscribe( signalname ) do |on|
      on.message() do |channel, msg|
        getInstance.unsubscribe()
      end
    end
  end

  def publishItemReadySignal
    publishSignal( @item_ready_signal )
  end

  def waitForItemReadySignal
    waitForSignal( @item_ready_signal )
  end

  def getItemIDFromState( *acceptable_states )
    item_id = nil
    found_state = nil
    while( item_id.nil? )
      acceptable_states.shuffle!
      curr_state = acceptable_states.pop
      break if curr_state.nil?
      curr_state = getProperState( curr_state )
      displayDebugMessage( "Attempting to grab item from state: #{ curr_state }." )
      item_id = getInstance.spop( curr_state )
      found_state = curr_state unless item_id.nil?
    end
    return [ item_id, found_state ]
  end

end
