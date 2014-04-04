
require 'dist/config/baseconfig'

module Dist

  class RunnerPhaseJobConfig

    include Helpers

    attr_reader :attributes

    def initialize( attributes )
      @attributes = attributes
    end

    def validate
      validate_keys_exist( @attributes, *( %w( job_class per_unit unit ) ) )

      raise "provided job_class #{ @attributes[ 'job_class' ] } is not an existent class." unless class_exists?( @attributes[ 'job_class' ] )
      @attributes[ 'per_unit' ] = Float( @attributes[ 'per_unit' ] )
      validate_time_interval_name( @attributes[ 'unit' ] )

      # TODO: Add validation if instance specific job attributes exist.
    end
  end

  class RunnerPhaseConfig

    include Helpers

    attr_reader :attributes

    def initialize( attributes )
      @attributes = attributes
    end

    def validate_and_format_count_and_duration
      total_count_exists = false
      phase_duration_exists = false

      if  @attributes.key?( 'total_count' )
        @attributes[ 'total_count' ] = Integer( @attributes[ 'total_count' ] )
        total_count_exists = true
      end

      if @attributes.key?( 'phase_duration' ) && @attributes.key?( 'phase_duration_units' )
        @attributes[ 'phase_duration' ] = Float( @attributes[ 'phase_duration' ] )
        validate_time_interval_name( @attributes[ 'phase_duration_units' ] )
        phase_duration_exists = true
      else
        # Ensure neither exist ( in case either one did )
        @attributes.delete( 'phase_duration' )
        @attributes.delete( 'phase_duration_units' )
      end

      # Both are allowed to exist, in which case which ever criteria is met first will terminate the phase.
      raise 'Either total_count or phase_duration must be provided for each phase definition.' unless total_count_exists || phase_duration_exists
    end

    def validate

      validate_keys_exist( @attributes, *( %w( name description jobs ) ) )

      validate_and_format_count_and_duration

      raise 'Jobs array incorrectly defined.' unless @attributes[ 'jobs' ].is_a?( Array )
      @attributes[ 'jobs' ].each { |j| RunnerPhaseJobConfig.new( j ).validate }

    end
  end

  class RunnerConfig < BaseConfig

    def validate

      super

      validate_keys_exist( @attributes, *( %w( base_attributes_file_path phases ) ) )

      # Now do more specific type/value validation
      @attributes[ 'base_attributes' ] = load_yaml_file( @attributes[ 'base_attributes_file_path' ] )

      raise 'Phases array incorrectly defined.' unless @attributes[ 'phases' ].is_a?( Array )
      @attributes[ 'phases' ].each { |p| RunnerPhaseConfig.new( p ).validate }

      # NOTE: use_poisson & continuous both rely on the falseness of non-existent values.
      #       but, ensure they are boolean values for later retrieval/comparison.
      @attributes[ 'use_poisson' ] = ( @attributes[ 'use_poisson' ] == true )
      @attributes[ 'continuous'  ] = ( @attributes[ 'continuous'  ] == true )

    end

  end

end
