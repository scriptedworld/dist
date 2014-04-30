

DIST is a distributed Job Execution Engine.

# Table of Contents

<!-- MarkdownTOC depth=3 -->

- Getting Started.
- Description of the framework:
- Description of each script:
  - Runner:
  - Reporter:
  - Manager:
  - Worker:
  - Additionally, soon to exist in it's own repo ( dist-graph ) repo: Data.
- Configuration files:
  - Common configuration items:
  - Runner Config File:
    - Runner Phase Configuration:
    - Runner Phase Job Configuration:
  - Reporter Config File:
  - Worker Config File:

<!-- /MarkdownTOC -->

# Getting Started.

You must have redis running somewhere. ( I tend to call this host aggr which is short for aggregator )

Appropriate support libraries have been included with the source distro, you can use bundle exec to use those versions. Or you can go through the Gemfile and ensure that you have all of the necessary support gems/libraries installed.

You *should* configure your system to have a high quantity of file descriptors available per process.  The included redis.conf sets maxclients to 100000 which will attempt to use 100000+ file descriptors within it's process. Describing the process is beyond this document.

# Description of the framework:

  Dist generally follows the chalkboard pattern of work distribution.  A single process is responsible for adding jobs to a job queue, which is constantly being polled by workers looking for work.  As they find jobs, they move the jobs through other job states.  REDIS was chosen as the database engine as it provides for some of the necessarily atomic transactions of the system internally.

  Other support scripts can be run to provide setup data, metrics during runtime, etc. but only the runner & workers are absolutely required ( other than having a running redis server to connect to ).

# Description of each script:

## dist-runner:

  Responsible for injecting jobs into job queue for workers to process.

  Normally runs on the aggr host.

  The runner is invoked providing a runner configuration file ( yaml-based ) as it's only command-line argument.

  The runner configuration sets up a number of general configuration values and then defines the phases of your test.

  Each phase of the test is defined by either a time-limit or a job-count limit as the phase termination condition.

  Each phase will define one or more job types to run and provide rates for each of those job types during the duration of the phase.

## dist-reporter:

  Gathers & stores metrics as long as it is running at a configuration driven interval.

  Normally runs on the aggr host.

  The reporter is invoked providing a reporter configuration file ( yaml-based ) as it's only command-line argument.

  The reporter configuration sets a number of general configuration values as well as specifying the metrics reporting interval.

## dist-manager:

  A script to wrap starting and/or stopping some quantity of Worker processes.

  The manager is usually invoked as follows:
  > "./manager.rb --action `<START|STOP|LIST>` --quantity 75 --command "./worker.rb ./data/worker_config.yaml"

  The manager is one of the only scripts in the Dist framework that doesn't following the configuration file-path as only argument pattern.

## dist-worker:

  Periodically polls the job queue for jobs in a 'READY' state, and begins running them. Working until completion or failure.

  Normally **NOT** run on the aggr host.

  While processing each job, the job state will be moved to 'PROCESSING'.

  Depending on the exit state of the job, the job data will be moved into a final 'BROKEN' or 'COMPLETE' state.

  The worker is invoked providing a worker configuration file ( yaml-based ) as it's only command-line argument.

  **NORMALLY** The worker is not invoked directly, but rather is run via the manager script to start/stop multiple instances at the same time.

  ( Example: I tend to run 75 copies of the worker on each of 8 hosts during my test runs. )

## The live data service:

  Provided in it's own repository as it is not strictly necessary. See https://github.com/a1ph4g33k/dist-graph
  
  The data service provides a live web interface & image generator for the metrics gathered by the reporter.

  Normally runs on the aggr host.

  The data service is not invoked directly, but rather through it's own start_dataserver.sh which runs the data service within Unicorn.

# Configuration files:

  Each of the runnable applications has it's own configuration file definition.

  Examples can be found in GitHub at: https://github.com/a1ph4g33k/dist/tree/master/data

## Common configuration items:

  * `name`: The name of the configuration file. Optionally, you can also add a 'description' value. The name will be logged during the script runtime, but generally exists
          to help when you have lots of configuration files.
  * `log_dir`: Where you want log files from the given script to be written to.
  * `redis_host`: host name or ip to talk to redis.
  * `redis_port`: port number to talk to redis.
  * `redis_pass`: redis server auth value. ( specified in your redis config. default provided in the example configs is 'slenderman' )
  * `debug`: true or false

## Runner Config File:

  The runner configuration file is the most complicated because it has a LOT to deal with.  Beyond the common configuration items two additional configuration values must be provided:

  * `base_attributes_file_path`: this provides a hash of attributes to pre-populate into each job as they are created.
  * `phases`: an array of phase definitions.

### Runner Phase Configuration:

  Each phase definition requires the following attributes:

  * `name`: The name of the phase.
  * `description`: The description of the phase.
  * `jobs`: The array of job definitions to create during the lifetime of the current phase.

  and

  * `total_count`: The total number of jobs which will be inserted during this phase. ( as opposed to `phase_duration` )

  or 

  * `phase_duration`: Numeric element of a timed length for the phase duration ( as opposed to `total_count` )
  and
  * `phase_duration_units`: The Units portion of the timed length. Values allowed include [ MILLIS, SECOND, MINUTE, HOUR, DAY, WEEK ]

### Runner Phase Job Configuration:

  Each Job defintion requires 3 attributes:

  * `job_class`: The complete class name of the Dist::Job derived class to instantiate.
  * `per_unit`: Numeric portion of the rate this job definition should be created at.
  * `unit`: As with `phase_duration_units` above, values allowed include [ MILLIS, SECOND, MINUTE, HOUR, DAY, WEEK ]


## Reporter Config File:

  The reporter configuration file is very basic. Beyond the common configuration values, only one additional attribute is required:

  * `report_interval_seconds`: The number of seconds between iterations of the reporter.

## Worker Config File:

  * `queue_method`: Either 'polling' or 'signals'

  'signals' only works for systems with a relatively low load. There are issues with REDIS switching back and forth between Normal
  & PubSub mode that causes issues ( unexpected messages during the PubSub wait that clients don't handle ).

  *IF* queue_method == 'polling' then additionally you must specify:

  * `polling_timing`: Either 'absolute' or 'randomized'
  * `polling_delay_seconds`: Number of seconds between Jobs.READY check in.

  *IF* polling_timing == 'randomized' then additionally you must specify:

  * `polling_delay_stdev` when using randomized timing, how much deviation around the core delay value to use.
