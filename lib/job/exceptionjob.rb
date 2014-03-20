
require 'job/job'

class ExceptionJob < Job
  def setup
    raise 'BLOW UP GOOD! Never come back!'
  end

  # Don't need to override run because it should never get called.

end
