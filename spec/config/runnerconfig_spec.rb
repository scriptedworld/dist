require 'spec_helper'
require 'dist/config/runnerconfig'

module Dist

  describe "Runner Configuration Files" do

    include Helpers
    include ConfigHelpers

    before( :all ) do

      @optional_params = %w( continuous use_poisson )

      job_base_attributes = { foo: 'bar' }
      @base_attributes_temp_file = createTempConfigFile( 'base_attributes', job_base_attributes )

      @all_attributes = Hash.new
      @all_attributes[ 'base_attributes_file_path' ] = @base_attributes_temp_file.path
      @all_attributes[ 'phases'                    ] = [
          { 'name' => 'name',
            'description' => 'description',
            'jobs' => [],
            'total_count' => 1
          }
      ]

      @attribute_hashes = Hash.new
      @attribute_hashes[ :all ] = @all_attributes
      @attribute_hashes[ :empty ] = Hash.new

      @all_attributes.keys().each do |curr_key|

        temp_hash = @all_attributes.dup()
        temp_hash.delete( curr_key )

        @attribute_hashes[ curr_key ] = temp_hash

      end

    end

    after( :all ) do
      cleanupTempConfigFile( @base_attributes_temp_file )
    end

    it "should be derived from BaseConfig" do

      withConfig( @attribute_hashes[ :all ], RunnerConfig, :include_base_attributes => true ) do |conf|
        expect( conf ).to be_a_kind_of( BaseConfig )
      end

    end

    it "requires the base_attributes_file_path parameter" do

      expectNewConfigToRaiseError( @attribute_hashes[ :empty ], RunnerConfig, "Key base_attributes_file_path missing.", :include_base_attributes => true )

    end

    it "requires a phases array of RunnerPhaseConfig objects." do

      expectNewConfigToRaiseError( @attribute_hashes[ 'phases' ], RunnerConfig, "Key phases missing.", :include_base_attributes => true )

      specific_attributes = @attribute_hashes[ 'phases' ].dup()
      specific_attributes[ 'phases' ] = Hash.new

      expectNewConfigToRaiseError( specific_attributes, RunnerConfig, "Phases array incorrectly defined.", :include_base_attributes => true )

    end

    it "handles the abscence of optional parameters ( 'continuous' & 'use_poisson' ) (default to false)." do
      withConfig( @attribute_hashes[ :all ], RunnerConfig, :include_base_attributes => true ) do |conf|
        @optional_params.each do |optional_param|
          expect( conf[ optional_param ] ).to be_false()
        end
      end
    end

    it "handles ensuring the boolean nature of the optional parameters." do

      @optional_params.each do |optional_param|

        specific_attributes = @all_attributes.dup
        specific_attributes[ optional_param ] = true

        withConfig( specific_attributes, RunnerConfig, :include_base_attributes => true ) do |conf|
          expect( conf[ optional_param ] ).to be_true()
        end

        # ANYTHING that is not an Instance of TrueClass is false.
        [ nil, 3.0, "true" ].each do |curr_false_value|

          specific_attributes[ optional_param ] = curr_false_value

          withConfig( specific_attributes, RunnerConfig, :include_base_attributes => true ) do |conf|
            expect( conf[ optional_param ] ).to be_false()
          end

        end

      end


    end

    it "creates & validates RunnerPhaseConfig objects for each hash in the phases array." do
      RunnerPhaseConfig.any_instance.should_receive( :validate ).once
      withConfig( @attribute_hashes[ :all ], RunnerConfig, :include_base_attributes => true ) do |conf|
        # Do nothing. #validate should have already been called.
      end
    end

    it "throws an exception during creation if any phase fails to validate." do
      RunnerPhaseConfig.any_instance.should_receive( :validate ) { raise "No!" }
      expectNewConfigToRaiseError( @attribute_hashes[ :all ], RunnerConfig, "No!", :include_base_attributes => true )
    end

  end

end
