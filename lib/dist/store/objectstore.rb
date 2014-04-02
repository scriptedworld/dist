
require 'set'
require 'redis'
require 'hiredis'
require 'json'
require 'yaml'

require 'dist/helpers'
require 'dist/logged'

module Dist

  class ObjectStore

    # include Helpers

    include Logged

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

    def set_host( new_host )
      @host = new_host
    end

    def get_host
      @host
    end

    def set_port( new_port )
      @port = new_port
    end

    def get_port
      @port
    end

    def set_pass( new_pass )
      @pass = new_pass
    end

    def get_pass
      @pass
    end

    def get_instance
      if @@instance.nil?
        raise 'Redis Host unconfigured.' if @host.nil?
        raise 'Redis Port unconfigured.' if @port.nil?
        raise 'Redis Pass unconfigured.' if @pass.nil?
        @@instance = Redis.new( host: @host, port: @port, driver: :hiredis )
        @@instance.auth( @pass )
      end
      @@instance
    end

    def disconnect
      unless @@instance.nil?
        @@instance.close
        @@instance = nil
      end
    end

    def set_item_prefix( new_prefix )
      @item_prefix = new_prefix
    end

    def get_item_prefix
      @item_prefix
    end

    def set_state_prefix( new_state_prefix )
      @state_prefix = new_state_prefix
    end

    def get_state_prefix
      @state_prefix
    end

    def set_allowed_states( *states )
      @allowed_states = Set.new
      states.each { |s| @allowed_states << get_proper_state( s ) }
    end

    def get_allowed_states
      @allowed_states.to_a
    end

    def get_proper_id( id )
      prepended = "#{ @item_prefix }#{ id }"
      ( id.to_s.start_with?( @item_prefix ) ) ? id : prepended
    end

    def get_proper_state( state )
      prepended = "#{ @state_prefix }#{ state }"
      ( state.to_s.start_with?( @state_prefix ) ) ? state : prepended
    end

    def load_item( id )
      item_id = get_proper_id( id )
      result = nil

      if get_instance.exists( item_id )
        display_debug_message( "Retrieving data for #{ item_id }" )
        result = YAML.load( get_instance.get( item_id ) )
        # result = JSON.parse( get_instance.get( item_id ) )
      else
        # Bad situation. Requested Item didn't exist.
        raise "Item #{ id } -> #{ item_id } not found."
      end
      result
    end

    def save_item( id, data )
      item_id = get_proper_id( id )
      display_debug_message( "Storing data as #{ id } -> #{ item_id }" )
      get_instance.set( item_id, data.to_yaml )
      # get_instance.set( item_id, data.to_json )
    end

    def check_item_exists( id )
      item_id = get_proper_id( id )
      get_instance.exists( item_id )
    end

    def get_item_state( id )
      item_id = get_proper_id( id )

      matches = @allowed_states.select { |s| get_instance.sismember( get_proper_state( s ), item_id ) }

      if matches.length > 0
        if matches.length > 1
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
    def set_item_state( id, new_state )

      new_state = get_proper_state( new_state )

      raise "Attempted to set item #{ id } to invalid state #{ new_state }." unless @allowed_states.include?( new_state )

      item_id = get_proper_id( id )
      curr_state = get_item_state( id )

      curr_state = get_proper_state( curr_state ) unless curr_state.nil?
      new_state = get_proper_state( new_state )

      # optimization, no point in a no-op.
      return if curr_state == new_state

      if curr_state.nil?
        # No prior state.
        display_debug_message( "Adding item to state #{ new_state }." )
        get_instance.sadd( new_state, item_id )
      else
        # Existing state.
        display_debug_message( "Moving item #{ item_id } to #{ new_state } from #{ curr_state.nil? ? 'nil' : curr_state }." )
        get_instance.smove( curr_state, new_state, item_id ) unless curr_state.nil?
      end

    end

    def get_new_item_id_key
      @item_id_key
    end

    def set_new_item_id_key( new_key )
      @item_id_key = new_key
    end

    def get_item_ready_signal_name
      @item_ready_signal
    end

    def set_item_ready_signal_name( new_signal_name )
      @item_ready_signal = new_signal_name
    end

    def set_next_new_item_id( new_value )
      new_value = Integer( new_value )
      get_instance.set( @item_id_key, new_value )
    end

    def get_new_item_id
      get_instance.incr( @item_id_key )
    end

    def publish_signal( signalname )
      get_instance.publish( signalname, '1' )
    end

    def wait_for_signal( signalname )
      get_instance.subscribe( signalname ) do |on|
        on.message do |channel, msg|
          get_instance.unsubscribe
        end
      end
    end

    def publish_item_ready_signal
      publish_signal( @item_ready_signal )
    end

    def wait_for_item_ready_signal
      wait_for_signal( @item_ready_signal )
    end

    def get_item_id_from_state( *acceptable_states )
      item_id = nil
      found_state = nil
      while item_id.nil?
        acceptable_states.shuffle!
        curr_state = acceptable_states.pop
        break if curr_state.nil?
        curr_state = get_proper_state( curr_state )
        display_debug_message( "Attempting to grab item from state: #{ curr_state }." )
        item_id = get_instance.spop( curr_state )
        found_state = curr_state unless item_id.nil?
      end

      # return retrieved item_id & state it is/was in.
      [ item_id, found_state ]
    end

  end

end
