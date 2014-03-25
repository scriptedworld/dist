
require 'dist/job/job'

module Dist

  class EmptyJob < Job
    def run
      # Do nothing, but override base implementation.
    end
  end

end
