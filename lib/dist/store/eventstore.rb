
require 'dist/store/objectstore'

module Dist

  class EventStore < ObjectStore

    def initialize
      super

      setItemReadySignalName( 'signal.event.ready' )
      setNewItemIDKey( 'new.event.number' )
      setItemPrefix( 'event.' )
      setStatePrefix( 'events.' )

      ### NOTE: There are no states for events. They are simply points in time.
      # setAllowedStates( )
    end

  end

end
