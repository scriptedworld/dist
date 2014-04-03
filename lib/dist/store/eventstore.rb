
require 'dist/store/objectstore'

module Dist

  class EventStore < ObjectStore

    def initialize
      super

      self.item_ready_signal = 'signal.event.ready'
      self.item_id_key = 'new.event.number'
      self.item_prefix = 'event.'
      self.state_prefix = 'events.'

      ### NOTE: There are no states for events. They are simply points in time.
      # self.allowed_states = []
    end

  end

end
