
require 'dist/job/job'

module Dist

  class JobExceptionJob < Job

    def teardown( e = nil )
      raise( JobException, 'BLOW UP a little, but we can recover.' ) if e.nil?
    end

    def run
      # Do nothing.
    end

  end

end
