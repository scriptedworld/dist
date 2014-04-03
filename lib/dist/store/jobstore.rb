
require 'dist/store/objectstore'

module Dist

  class JobStore < ObjectStore

    def initialize
      super

      self.item_ready_signal = 'signal.job.ready'
      self.item_id_key = 'new.job.number'
      self.item_prefix = 'job.'
      self.state_prefix = 'jobs.'
      self.allowed_states = %w( INITIAL READY PROCESSING COMPLETE BROKEN )
    end

  end

end
