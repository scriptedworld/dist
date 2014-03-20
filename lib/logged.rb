
require 'helpers'

module Logged

  def logging_name
    self.class.to_s
  end

  def displayMessage( level, msg )
    get_logger_collection().each do |curr_logger|
      curr_logger.send( level, logging_name ) { msg }
    end
  end

  def displayErrorMessage( msg )
    displayMessage( :error, msg )
  end

  def displayDebugMessage( msg )
    displayMessage( :debug, msg )
  end

  def get_logger_collection

    if( $loggers.nil? )
      $loggers = Hash.new
    end

    if( ! $loggers.include?( logging_name ) )
      curr_logger_array = []

      basic_formatter = Logger::Formatter.new

      std_logger = Logger.new( STDOUT )

      std_logger.formatter = proc do |severity, datetime, progname, msg|
        basic_formatter.call( severity,
                              datetime,
                              progname,
                              msg.ai( plain:     false,
                                      index:     true,
                                      multiline: true,
                                      indent:    2,
                                      sort_keys: true ) )
      end

      curr_logger_array << std_logger

      if( ( ! $config.nil? ) && $config.include?( 'log_dir' ) )

        # FIXME: Should probably include PID in the log file name so that
        #        multiple scripts using things like Job or JobStore don't
        #        mangle each others log files.
        log_file = File.new( File.join( $config[ 'log_dir' ], "#{ logging_name }.log" ), 'w+' )
        file_logger = Logger.new( log_file )

        file_logger.formatter = proc do |severity, datetime, progname, msg|
          basic_formatter.call( severity,
                                datetime,
                                progname,
                                msg.ai( plain:     true,
                                        index:     false,
                                        multiline: false,
                                        sort_keys: true ) )
        end

        curr_logger_array << file_logger

      end

      $loggers[ logging_name ] = curr_logger_array
    end

    $loggers[ logging_name ]

  end

end
