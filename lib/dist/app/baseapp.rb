require 'dist/helpers'
require 'dist/logged'

module Dist

  class BaseApp

    include Helpers
    include Logged

    def config_class
      # This *SHOULD* get overriden in each child of BaseApp ... warn the user if they missed a step.
      display_debug_message( 'WARNING: BaseApp#config_class used.' )

      # return the BaseConfig class.
      BaseConfig
    end

    # This should NOT be overriden.
    # TODO: Add code here to make sure that run has NOT been overriden.
    def run
      load_config
      instance_run
    end

    def instance_run
      raise 'This method instance_run must be implemented in all App classes deriving from BaseApp.'
    end

    def load_config

      config_klass = config_class
      @config = config_klass.new( ARGV.pop )

      handle_redis_config( @config[ 'redis_host' ], @config[ 'redis_port' ], @config[ 'redis_pass' ] )

    end

  end

end
