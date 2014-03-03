DIST is a distributed Job Execution Engine.

# Getting Started.

You must have redis running somewhere. ( I tend to call this host aggr which is short for aggregator )

Appropriate support libraries have been included with the source distro, you can use bundle exec to use those versions. Or you can go through the Gemfile and ensure that you have all of the necessary support gems/libraries installed.

You *should* configure your system to have a high quantity of file descriptors available per process.  The included redis.conf sets maxclients to 100000 which will attempt to use 100000+ file descriptors within it's process. Describing the process is beyond this document.

# Description of the framework:

  Dist generally follows the chalkboard pattern of work distribution.  A single process is responsible for adding jobs to a job queue, which is constantly being polled by workers looking for work.  As they find jobs, they move the jobs through other job states.  REDIS was chosen as the database engine as it provides for some of the necessarily atomic transactions of the system internally.

  Other support scripts can be run to provide setup data, metrics during runtime, etc. but only the runner & workers are absolutely required ( other than having a running redis server to connect to ).

# Description of each script:

## Runner:

  Responsible for injecting jobs into job queue for workers to process.

  Normally runs on the aggr host.

  Runner is invoked providing a runner configuration file ( yaml-based ) as it's only command-line argument.

  The Runner Configuration sets up a number of general configuration values and then defines the phases of your test.

  Each phase of the test is defined by either a time-limit or a job-count limit as the phase termination condition.

  Each phase will define one or more job types to run and provide rates for each of those job types during the duration of the phase.

## Reporter:

  Gathers & stores metrics as long as it is running at a configuration driven interval.

  Normally runs on the aggr host.

  Reporter is invoked providing a reporter configuration file ( yaml-based ) as it's only command-line argument.

  The Reporter configuration sets a number of general configuration values as well as specifying the metrics reporting interval.

## Manager:

  A script to wrap starting and/or stopping some quantity of Worker processes.

  Manager is usually invoked as follows:
  > "./manager.rb --action `<START|STOP|LIST>` --quantity 75 --command "./worker.rb ./data/worker_config.yaml"

  Manager is one of the only scripts in the Dist framework that doesn't following the configuration file-path as only argument pattern.

## Worker:

  Periodically polls the job queue for jobs in a 'READY' state, and begins running them. Working until completion or failure.

  Normally **NOT** run on the aggr host.

  While processing each job, the job state will be moved to 'PROCESSING'.

  Depending on the exit state of the job, the job data will be moved into a final 'BROKEN' or 'COMPLETE' state.

  Worker is invoked providing a worker configuration file ( yaml-based ) as it's only command-line argument. 

  **NORMALLY** Worker is not invoked directly, but rather is run via the Manager script to start/stop multiple instances at the same time.

  ( Example: I tend to run 75 copies of the worker on each of 8 hosts during my test runs. )

## Data:

  Data provides a live web interface to the metrics gathered by the Reporter.

  Normally runs on the aggr host.

  Data is not invoked directly, but rather through start_dataserver.sh which starts the data script using the Unicorn web server engine, making it parallelized.

