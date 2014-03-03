
require './lib/job/job.rb'

class EmptyJob < Job
  def run
    # Do nothing, but override base implementation.
  end
end
