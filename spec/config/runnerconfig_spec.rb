require 'spec_helper'
require 'dist/config/runnerconfig'

module Dist

  describe 'Runner Configuration Files' do

    include Helpers
    include ConfigHelpers

    before( :all ) do

      @optional_params = %w( continuous use_poisson )

      job_base_attributes = { foo: 'bar' }
      @base_attributes_temp_file = create_temp_config_file( 'base_attributes', job_base_attributes, disable_base_attributes: true )

      @all_attributes = {}
      @all_attributes[ 'base_attributes_file_path' ] = @base_attributes_temp_file.path
      @all_attributes[ 'phases'                    ] = [
        {
          'name'        => 'name',
          'description' => 'description',
          'jobs'        => [],
          'total_count' => 1
        }
      ]

      @attribute_hashes = {}
      @attribute_hashes[ :all ] = @all_attributes
      @attribute_hashes[ :empty ] = {}

      @all_attributes.keys.each do |curr_key|

        temp_hash = @all_attributes.dup
        temp_hash.delete( curr_key )

        @attribute_hashes[ curr_key ] = temp_hash

      end

    end

    after( :all ) do
      cleanup_temp_config_file( @base_attributes_temp_file )
    end

    it 'should be derived from BaseConfig' do
      kind_of_baseconfig( @attribute_hashes[ :all ], RunnerConfig )
    end

    it 'requires the base_attributes_file_path parameter' do

      expect_new_config_to_raise_error( @attribute_hashes[ :empty ], RunnerConfig, 'Key base_attributes_file_path missing.' )

    end

    it 'requires a phases array of RunnerPhaseConfig objects.' do

      expect_new_config_to_raise_error( @attribute_hashes[ 'phases' ], RunnerConfig, 'Key phases missing.' )

      specific_attributes = @attribute_hashes[ 'phases' ].dup
      specific_attributes[ 'phases' ] = {}

      expect_new_config_to_raise_error( specific_attributes, RunnerConfig, 'Phases array incorrectly defined.' )

    end

    it 'handles the abscence of optional parameters ( "continuous" & "use_poisson" ) (default to false).' do
      with_config( @attribute_hashes[ :all ], RunnerConfig ) do |conf|
        @optional_params.each do |optional_param|
          expect( conf[ optional_param ] ).to be_falsey
        end
      end
    end

    it 'handles ensuring the boolean nature of the optional parameters.' do

      @optional_params.each do |optional_param|

        specific_attributes = @all_attributes.dup
        specific_attributes[ optional_param ] = true

        with_config( specific_attributes, RunnerConfig ) do |conf|
          expect( conf[ optional_param ] ).to be_truthy
        end

        # ANYTHING that is not an Instance of TrueClass is false.
        [ nil, 3.0, 'true' ].each do |curr_false_value|

          specific_attributes[ optional_param ] = curr_false_value

          with_config( specific_attributes, RunnerConfig ) do |conf|
            expect( conf[ optional_param ] ).to be_falsey
          end

        end

      end

    end

    it 'creates & validates RunnerPhaseConfig objects for each hash in the phases array.' do
      expect_any_instance_of( RunnerPhaseConfig ).to receive( :validate ).once
      with_config( @attribute_hashes[ :all ], RunnerConfig ) do |_conf|
        # Do nothing. #validate should have already been called.
      end
    end

    it 'throws an exception during creation if any phase fails to validate.' do
      expect_any_instance_of( RunnerPhaseConfig ).to receive( :validate ) { raise 'No!' }
      # RunnerPhaseConfig.any_instance.should_receive( :validate ) { raise 'No!' }
      expect_new_config_to_raise_error( @attribute_hashes[ :all ], RunnerConfig, 'No!' )
    end

  end

end
