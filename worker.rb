#!/usr/bin/env ruby

require './lib/helpers.rb'
require './lib/config/workerconfig.rb'

def waitForJobViaSignalling( job_store, config )
  displayDebugMessage( 'No jobs ready, waiting for signal.' )
  job_store.waitForItemReadySignal()
end

def waitForJobViaPolling( job_store, config )
  waitSeconds( config[ 'polling_delay_seconds' ], ( config[ 'polling_timing' ] == 'absolute' ), config[ 'polling_delay_stdev' ] )
end

def getReadyJob( job_store, config )

  parts = job_store.getItemIDFromState( 'READY' )

  job_id = parts.nil? ? nil : parts[0]
  output = nil

  unless( ( job_id.is_a?( String ) ) and ( job_id.start_with?( job_store.getItemPrefix() ) ) )

    # See below, waitForJob is an alias.
    waitForJob( job_store, config )

  else

    job_attributes = job_store.loadItem( job_id )
    job_class = job_attributes[ 'job_class' ]

    job_klass = Object::const_get( job_class )
    raise "Inappropriate job_class provided: #{ job_class }" unless job_klass.ancestors.include?( Job )

    # Since I've already loaded the attributes for this job, I don't need to do 
    # it again. Build our Job object instead of letting the constructor 
    # duplicate the work done above.
    output = job_klass.new()
    output.setItemID( job_id )
    output.setAttributes( job_attributes )

  end

  output
end

# User ^C ... shutdown politely.
Signal.trap( 'INT' ) { exit! }

# Polite termination request.
Signal.trap( 'TERM' ) { exit! }

# Terminated Ordered.
Signal.trap( 'KILL' ) { exit! }

# Load & validate configuration as the only expected parameter to the script.
config = WorkerConfig.new( ARGV.pop )
handleRedisConfig( config[ 'redis_host' ], config[ 'redis_port' ], config[ 'redis_pass' ] )

# NOTE: Here we pull a rubyism ... replace watForJob with the correct method 
#       based on configuration. This way, when we're in the middle of handling 
#       jobs, we don't have to check this value each time.
case( config[ 'queue_method' ] )
  when 'signals' then
    alias :waitForJob :waitForJobViaSignalling
  when 'polling' then
    alias :waitForJob :waitForJobViaPolling
end

j = JobStore.new

while( true ) do
  begin
    job = getReadyJob( j, config )
    job.handleLifecycle() unless job.nil?
  rescue => e

    # Show the error on stderr.
    displayErrorMessage( e.message )
    displayErrorMessage( e.backtrace )

    if( $DEBUG )
      require 'pry'
      binding.pry
    end

    j.disconnect
    j = JobStore.new

    retry

  end
end

