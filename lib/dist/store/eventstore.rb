
require 'dist/store/objectstore'

module Dist

  class EventStore < ObjectStore

    def initialize
      super

      set_item_ready_signal_name( 'signal.event.ready' )
      set_new_item_id_key( 'new.event.number' )
      set_item_prefix( 'event.' )
      set_state_prefix( 'events.' )

      ### NOTE: There are no states for events. They are simply points in time.
      # set_allowed_states( )
    end

  end

end
