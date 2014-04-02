
require 'dist/store/objectstore'

module Dist

  class JobStore < ObjectStore

    def initialize
      super

      set_item_ready_signal_name( 'signal.job.ready' )
      set_new_item_id_key( 'new.job.number' )
      set_item_prefix( 'job.' )
      set_state_prefix( 'jobs.' )
      set_allowed_states( *( %w( INITIAL READY PROCESSING COMPLETE BROKEN ) ) )
    end

  end

end
