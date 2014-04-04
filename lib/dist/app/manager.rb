#!/usr/bin/env ruby

require 'fileutils'
require 'optparse'
require 'yaml'

require 'dist/helpers'

module Dist

  class ManageWorkers

    def initialize

      @options                      = {}
      @options[:default_piddir]     = './pids/'
      @options[:default_quantity]   = 10
      @options[:default_delay]      = 0.0

      @options[:piddir]             = @options[:default_piddir]
      @options[:quantity]           = @options[:default_quantity]
      @options[:delay]              = @options[:default_delay]
      @options[:command]            = nil
      @options[:action]             = nil

      parse_command_line
    end

    def handle_option_parser

      OptionParser.new do |opts|

        opts.on( '--piddir PIDDIR', "Where to write PID files to. Default: #{ @options[:default_piddir] }" ) do |value|
          @options[:piddir] = value
        end

        opts.on( '--action START|STOP|LIST', 'Action to take. Start, Stop, or List Workers.' ) do |value|
          @options[:action] = value.upcase
        end

        opts.on( '--quantity QUANTITY', "How many workers to take this action for. Default: #{ @options[:default_quantity] }" ) do |value|
          @options[:quantity] = value.to_i
        end

        opts.on( '--delay DELAY_SECS', "How many seconds to delay between starting workers. Default: #{ @options[:default_delay] }" ) do |value|
          @options[:delay] = value.to_f
        end

        opts.on( '--command COMMAND', 'What command to execute?' ) do |value|
          @options[:command] = value
        end

      end.parse!

    end

    def parse_command_line

      handle_option_parser

      # Ensure our directories exist.
      FileUtils.mkdir_p( @options[:piddir] ) unless File.exist?( @options[:piddir] )

      # Validate arguments.

      assert( %w( START STOP LIST ).include?( @options[:action] ), "Action must either 'START', 'STOP' or 'LIST'." )

      # Quantity matters for START & STOP actions.
      assert( ( @options[:quantity] > 0 ), 'Quantity must be greater than 0.' ) unless @options[:action] == 'LIST'

      # Command only matters for START actions.
      assert_not_empty( @options[:command], 'Command must be provided.' ) if @options[:action] == 'START'

    end

    def fork_subprocess

      pid = fork

      if pid.nil?
        # We're in the child

        display_debug_message( "Exec: #{ @options[:command] }" )
        exec( @options[:command] )

        # We shouldn't ever get here ... but we'll put in an exit just in case.
        exit!
      else
        # We're in the parent.

        Process.detach( pid )
        return pid

      end

    end

    def enumerate_workers

      @known_pids = []

      # Iterate over all files in the @options[:piddir] directory. Each *SHOULD* only contain a process ID.
      Dir.glob( "#{ @options[:piddir] }*.pid" ) do |curr_file|

        # Ignore directories
        next if File.directory?( curr_file )

        begin
          curr_yaml = YAML.load_file( curr_file )

          if curr_yaml[:desc] == 'PID FILE'
            curr_pid = curr_yaml[:pid]
            valid_process = true

            # Validate that each of the process IDs harvested from PID files are running.
            begin
              Process.kill( 0, curr_pid )
            rescue Errno::ESRCH
              valid_process = false
            end

            @known_pids << curr_pid if valid_process

          end
        rescue
          # Something happened during parsing & status check. Consider this file invalid and delete it.
          File.unlink( curr_file )

          # Move on to the next file.
          next
        end

      end

    end

    def start_worker

      pid = fork_subprocess

      # After we've started the process, create a PID file based on a YAML representation of things.
      File.open( "#{ @options[:piddir] }#{ pid }.pid", 'w' ) do |file|
        file << { desc: 'PID FILE', pid: pid }.to_yaml
      end

      display_debug_message( "Started Worker: #{ pid }" )

    end

    def build_process_tree

      proc_tree = Hash.new { |ht, k| ht[k] = Array.new }
      proc_list = `ps -eo pid,ppid`.scan( /\d+/ )

      # To begin, populate things based on what we know ( only 1 generation )
      proc_list.each_slice( 2 ) do |curr_slice|
        child_pid = curr_slice[0].to_i
        parent_pid = curr_slice[1].to_i

        proc_tree[ parent_pid ] << child_pid
        proc_tree[ child_pid ] = []
      end

      # Now we must loop until we have no more generations to account for.

      modifications_made = true

      until modifications_made == false

        modifications_made = false

        proc_tree.keys.each do |curr_key|

          # Snapshot children before update.
          children_before = proc_tree[ curr_key ].uniq.sort

          # Iterate each child and include their children as the parents children

          proc_tree[ curr_key ].each do |curr_child|
            proc_tree[curr_key] += proc_tree[ curr_child ]
          end

          # Snapshot children after update.
          children_after = proc_tree[ curr_key ].uniq.sort

          # Check for modifications.
          modifications_made = ( modifications_made || ( children_before != children_after ) )
          proc_tree[curr_key] = children_after

        end

      end

      # We should be done. Return what we have.
      proc_tree

    end

    def kill_process( pid )
      display_debug_message( "Killing Process: #{ pid }" )
      Process.kill( 'TERM', pid )
    rescue Errno::ESRCH
      # We got a no process error, which is fine in this case. Log it to make this visible.
      display_error_message( 'Errno::ESRCH rescued & ignored by ManageWorkers.' )
    end

    def stop_worker

      assert( @known_pids.length > 0, 'Not enough processes found to fulfill request.' )

      pid = @known_pids[ rand( @known_pids.length ) ]

      proc_tree = build_process_tree

      # Kill children.
      proc_tree[ pid ].each do |curr_child|
        kill_process( curr_child )
      end

      # Kill parent.
      kill_process( pid )

      # Clean up PID file.
      File.unlink( "#{ @options[:piddir] }#{ pid }.pid" )
    end

    def run

      if @options[:action] == 'START'
        @options[:quantity].times do
          start_worker
          sleep( @options[:delay] )
        end
      end

      if @options[:action] == 'STOP'
        @options[:quantity].times do

          enumerate_workers
          stop_worker

        end
      end

      # We're done, now show the user what processes we know about.
      enumerate_workers

      puts( 'Known Workers:' )
      puts( @known_pids.to_yaml )

    end

  end

end
