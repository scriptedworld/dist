require 'spec_helper'
require 'config/runnerconfig'

describe "Runner Configuration Files" do

  include ConfigHelpers

  before( :all ) do

    @optional_params = %w( continuous use_poisson )

    base_attributes_temp_file = createTempConfig( 'base_attributes', { foo: 'bar' } )

    @all_attributes = Hash.new
    @all_attributes[ 'base_attributes_file_path' ] = base_attributes_temp_file.path
    @all_attributes[ 'phases'                    ] = [
      { 'name' => 'name',
        'description' => 'description',
        'jobs' => [],
        'total_count' => 1
      }
    ]

    @temp_files = Hash.new
    @temp_files[ 'all'             ] = createAdvancedTempConfig( 'all', @all_attributes )
    @temp_files[ 'empty'           ] = createAdvancedTempConfig( 'empty' )
    @temp_files[ 'base_attributes' ] = base_attributes_temp_file

    @all_attributes.keys().each do |curr_key|

      temp_hash = @all_attributes.dup()
      temp_hash.delete( curr_key )

      @temp_files[ curr_key ] = createAdvancedTempConfig( curr_key, temp_hash )

    end

  end

  after( :all ) do
    cleanupTempConfigList( @temp_files.values )
  end

  it "should be derived from BaseConfig" do

    conf = RunnerConfig.new( @temp_files[ 'all' ].path )
    conf.should be_a( BaseConfig )

  end

  it "requires the base_attributes_file_path parameter" do

    expect { RunnerConfig.new( @temp_files[ 'base_attributes_file_path' ].path ) }.to raise_error( "Key base_attributes_file_path missing." )

  end

  it "requires a phases array of RunnerPhaseConfig objects." do

    expect { RunnerConfig.new( @temp_files[ 'phases' ].path ) }.to raise_error( "Key phases missing." )

    specific_attributes = @all_attributes.dup
    specific_attributes[ 'phases' ] = Hash.new

    withAdvancedTempConfigBasedOnAttributes( specific_attributes ) do |temp_file|
      expect { RunnerConfig.new( temp_file.path ) }.to raise_error( "Phases array incorrectly defined." )
    end

  end

  it "handles the abscence of optional parameters ( 'continuous' & 'use_poisson' ) (default to false)." do
    cfg = RunnerConfig.new( @temp_files[ 'all' ].path )
    @optional_params.each { |optional_param| expect( cfg[ optional_param ] ).to be_false() }
  end

  it "handles ensuring the boolean nature of the optional parameters." do

    @optional_params.each do |optional_param|

      specific_attributes = @all_attributes.dup
      specific_attributes[ optional_param ] = true

      withAdvancedTempConfigBasedOnAttributes( specific_attributes ) do |temp_file|
        RunnerConfig.new( temp_file.path )[ optional_param ].should be_true()
      end

      # ANYTHING that is not an Instance of TrueClass is false.
      [ nil, 3.0, "true" ].each do |curr_false_value|

        specific_attributes[ optional_param ] = curr_false_value

        withAdvancedTempConfigBasedOnAttributes( specific_attributes ) do |temp_file|
          RunnerConfig.new( temp_file.path )[ optional_param ].should be_false()
        end

      end

    end


  end

  it "creates & validates RunnerPhaseConfig objects for each hash in the phases array." do
    RunnerPhaseConfig.any_instance.should_receive( :validate ).once
    RunnerConfig.new( @temp_files[ 'all' ].path )
  end

  it "throws an exception during creation if any phase fails to validate." do
    RunnerPhaseConfig.any_instance.should_receive( :validate ) { raise "No!" }
    expect { RunnerConfig.new( @temp_files[ 'all' ].path ) }.to raise_error( "No!" )
  end

end
