
require 'config/baseconfig'

class RunnerPhaseJobConfig

  attr_reader :attributes

  def initialize( attributes )
    @attributes = attributes
  end

  def validate
    validateKeysExist( @attributes, *( %w( job_class per_unit unit ) ) )

    raise "provided job_class #{ @attributes[ 'job_class' ] } is not an existent class." unless class_exists?( @attributes[ 'job_class' ] )
    @attributes[ 'per_unit' ] = Float( @attributes[ 'per_unit' ] )
    validateTimeIntervalName( @attributes[ 'unit' ] )

    # TODO: Add validation if instance specific job attributes exist.
  end
end

class RunnerPhaseConfig

  attr_reader :attributes

  def initialize( attributes )
    @attributes = attributes
  end

  def validate

    validateKeysExist( @attributes, *( %w( name description jobs ) ) )

    totalCountExists = false
    phaseDurationExists = false

    if( @attributes.key?( 'total_count' ) )
      @attributes[ 'total_count' ] = Integer( @attributes[ 'total_count' ] )
      totalCountExists = true
    end

    if( @attributes.key?( 'phase_duration' ) and @attributes.key?( 'phase_duration_units' ) )
      @attributes[ 'phase_duration' ] = Float( @attributes[ 'phase_duration' ] )
      validateTimeIntervalName( @attributes[ 'phase_duration_units' ] )
      phaseDurationExists = true
    else
      # Ensure neither exist ( in case either one did )
      @attributes.delete( 'phase_duration' )
      @attributes.delete( 'phase_duration_units' )
    end

    # Both are allowed to exist, in which case which ever criteria is met first will terminate the phase.
    raise "Either total_count or phase_duration must be provided for each phase definition." unless totalCountExists or phaseDurationExists

    raise "Jobs array incorrectly defined." unless @attributes[ 'jobs' ].is_a?( Array )
    @attributes[ 'jobs' ].each { |j| RunnerPhaseJobConfig.new( j ).validate() }

  end
end

class RunnerConfig < BaseConfig

  def validate

    super

    validateKeysExist( @attributes, *( %w( base_attributes_file_path phases ) ) )

    # Now do more specific type/value validation
    @attributes[ 'base_attributes' ] = loadYAMLFile( @attributes[ 'base_attributes_file_path' ] )

    raise "Phases array incorrectly defined." unless @attributes[ 'phases' ].is_a?( Array )
    @attributes[ 'phases' ].each { |p| RunnerPhaseConfig.new( p ).validate() }

    # NOTE: use_poisson & continuous both rely on the falseness of non-existent values.
    #       but, ensure they are boolean values for later retrieval/comparison.
    @attributes[ 'use_poisson' ] = ( @attributes[ 'use_poisson' ] == true )
    @attributes[ 'continuous'  ] = ( @attributes[ 'continuous'  ] == true )

  end

end

