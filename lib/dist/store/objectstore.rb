
require 'set'
require 'redis'
require 'hiredis'
require 'json'
require 'yaml'
require 'singleton'

require 'dist/logged'

module Dist

  class ObjectStore

    include Singleton

    include Logged

    class <<self
      attr_accessor :redis_host
      attr_accessor :redis_port
      attr_accessor :redis_pass
    end

    attr_accessor :host
    attr_accessor :port
    attr_accessor :pass

    attr_accessor :item_prefix
    attr_accessor :state_prefix
    attr_accessor :item_id_key
    attr_accessor :item_ready_signal

    # For testing, not for general use.
    attr_writer :redis_instance

    def initialize
      @item_ready_signal = 'signal.object.ready'
      @item_id_key       = 'new.object.number'
      @item_prefix       = 'object.'
      @state_prefix      = 'objects.'
      @allowed_states    = Set.new

      @host              = ObjectStore.redis_host
      @port              = ObjectStore.redis_port
      @pass              = ObjectStore.redis_pass

      @redis_instance    = nil
    end

    # Wrapper for @redis_instance attribute that will connect when needed.
    # SEE ALSO: disconnect
    def redis_instance
      if @redis_instance.nil?
        raise 'Redis Host unconfigured.' if @host.nil?
        raise 'Redis Port unconfigured.' if @port.nil?
        raise 'Redis Pass unconfigured.' if @pass.nil?
        @redis_instance = Redis.new( host: @host, port: @port, driver: :hiredis )
        @redis_instance.auth( @pass )
      end
      @redis_instance
    end

    # Disconnects & removes reference to @redis_instance.
    # SEE ALSO: redis_instance
    def disconnect
      unless @redis_instance.nil?
        @redis_instance.close
        @redis_instance = nil
      end
    end

    def allowed_states=( states )
      if states.respond_to?( :each )
        @allowed_states = Set.new
        states.each { |s| @allowed_states << proper_state( s ) }
      end
    end

    def allowed_states
      @allowed_states.to_a
    end

    def proper_id( id )
      prepended = "#{ @item_prefix }#{ id }"
      ( id.to_s.start_with?( @item_prefix ) ) ? id : prepended
    end

    def proper_state( state )
      prepended = "#{ @state_prefix }#{ state }"
      ( state.to_s.start_with?( @state_prefix ) ) ? state : prepended
    end

    def load_item( id )
      item_id = proper_id( id )
      result = nil

      if redis_instance.exists( item_id )
        display_debug_message( "Retrieving data for #{ item_id }" )
        result = YAML.load( redis_instance.get( item_id ) )
        # result = JSON.parse( redis_instance.get( item_id ) )
      else
        # Bad situation. Requested Item didn't exist.
        raise "Item #{ id } -> #{ item_id } not found."
      end
      result
    end

    def save_item( id, data )
      item_id = proper_id( id )
      display_debug_message( "Storing data as #{ id } -> #{ item_id }" )
      redis_instance.set( item_id, data.to_yaml )
      # redis_instance.set( item_id, data.to_json )
    end

    def check_item_exists( id )
      item_id = proper_id( id )
      redis_instance.exists( item_id )
    end

    def current_item_state( id )
      item_id = proper_id( id )

      matches = @allowed_states.select { |s| redis_instance.sismember( proper_state( s ), item_id ) }

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
    def update_item_state( id, new_state )

      new_state = proper_state( new_state )

      raise "Attempted to set item #{ id } to invalid state #{ new_state }." unless @allowed_states.include?( new_state )

      item_id = proper_id( id )
      curr_state = current_item_state( id )

      curr_state = proper_state( curr_state ) unless curr_state.nil?
      new_state = proper_state( new_state )

      # optimization, no point in a no-op.
      return if curr_state == new_state

      if curr_state.nil?
        # No prior state.
        display_debug_message( "Adding item to state #{ new_state }." )
        redis_instance.sadd( new_state, item_id )
      else
        # Existing state.
        display_debug_message( "Moving item #{ item_id } to #{ new_state } from #{ curr_state }." )
        redis_instance.smove( curr_state, new_state, item_id )
      end

    end

    def update_next_item_id( new_value )
      new_value = Integer( new_value )
      redis_instance.set( @item_id_key, new_value )
    end

    def next_item_id
      redis_instance.incr( @item_id_key )
    end

    def publish_signal( signalname )
      redis_instance.publish( signalname, '1' )
    end

    def wait_for_signal( signalname )
      redis_instance.subscribe( signalname ) do |on|
        on.message do |_channel, _msg|
          redis_instance.unsubscribe
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
        curr_state = proper_state( curr_state )
        display_debug_message( "Attempting to grab item from state: #{ curr_state }." )
        item_id = redis_instance.spop( curr_state )
        found_state = curr_state unless item_id.nil?
      end

      # return retrieved item_id & state it is/was in.
      [ item_id, found_state ]
    end

  end

end
