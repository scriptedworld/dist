
require 'fileutils'

require 'dist/helpers'

module Dist

  module Logged

    def self.loggers
      @loggers ||= {}
    end

    def logging_name
      self.class.to_s
    end

    def display_message( level, msg )
      logger_collection.each do |curr_logger|
        curr_logger.send( level, logging_name ) { msg }
      end
    end

    def display_error_message( msg )
      display_message( :error, msg )
    end

    def display_debug_message( msg )
      display_message( :debug, msg )
    end

    def gen_formatter_proc( inspect_attributes )
      basic_formatter = Logger::Formatter.new

      proc do |severity, datetime, progname, msg|
        basic_formatter.call( severity,
                              datetime,
                              progname,
                              msg.ai( inspect_attributes ) )

      end
    end

    def logger_collection

      loggers = Logged.loggers

      unless loggers.include?( logging_name )
        curr_logger_array = []

        std_logger = Logger.new( STDOUT )
        std_logger.formatter = gen_formatter_proc( plain: false,
                                                   index: true,
                                                   multiline: true,
                                                   indent: 2,
                                                   sort_keys: true )

        curr_logger_array << std_logger

        if ENV.key?( 'DIST_LOG_DIR' )

          log_dir_path = ENV[ 'DIST_LOG_DIR' ]
          FileUtils.mkpath( log_dir_path )

          # FIXME: Should probably include PID in the log file name so that
          #        multiple scripts using things like Job or JobStore don't
          #        mangle each others log files.
          log_file = File.new( File.join( log_dir_path, "#{ logging_name }.log" ), 'w+' )

          file_logger = Logger.new( log_file )
          file_logger.formatter = gen_formatter_proc( plain: true,
                                                      index: false,
                                                      multiline: false,
                                                      sort_keys: true )

          curr_logger_array << file_logger

        end

        loggers[ logging_name ] = curr_logger_array
      end

      loggers[ logging_name ]

    end

  end

end
