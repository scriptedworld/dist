
require './lib/helpers.rb'

class BaseApp

  include Logged

  def getConfigClass
    # This *SHOULD* get overriden in each child of BaseApp ... warn the user if they missed a step.
    displayDebugMessage( "WARNING: BaseApp#getConfigClass used." )

    # return the BaseConfig class.
    BaseConfig
  end

  # This should NOT be overriden.
  # TODO: Add code here to make sure that run has NOT been overriden.
  def run
    loadConfig()
    instance_run()
  end

  def instance_run
    raise "This method instance_run must be implemented in all App classes deriving from BaseApp."
  end

  def loadConfig

    config_class = getConfigClass()
    $config = config_class.new( ARGV.pop )

    handleRedisConfig( $config[ 'redis_host' ], $config[ 'redis_port' ], $config[ 'redis_pass' ] )

  end

end
