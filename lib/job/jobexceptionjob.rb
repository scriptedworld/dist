
require './lib/job/job.rb'

class JobExceptionJob < Job

  def teardown( e = nil )
    if( e.nil? )
      raise JobException.new( 'BLOW UP a little, but we can recover.' )
    end
  end

  def run
    # Do nothing.
  end

end

