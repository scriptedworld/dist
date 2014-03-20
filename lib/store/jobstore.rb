
require 'store/objectstore'

class JobStore < ObjectStore

  def initialize
    super

    setItemReadySignalName( 'signal.job.ready' )
    setNewItemIDKey( 'new.job.number' )
    setItemPrefix( 'job.' )
    setStatePrefix( 'jobs.' )
    setAllowedStates( *( %w( INITIAL READY PROCESSING COMPLETE BROKEN ) ) )
  end

end
