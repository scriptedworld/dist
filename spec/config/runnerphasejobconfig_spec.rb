require 'spec_helper'
require 'dist/config/runnerconfig'

module Dist

  describe 'Runner Phase Job Configuration Objects' do

    include Helpers
    include ConfigHelpers

    before( :all ) do

      @all_attributes = Hash.new
      @all_attributes[ 'job_class' ] = 'Dist::EmptyJob'
      @all_attributes[ 'per_unit' ] = 1
      @all_attributes[ 'unit' ] = 'SECOND'

      @empty = {}

    end

    it 'should NOT be derived from BaseConfig' do

      expect( RunnerPhaseJobConfig.new( {} ) ).to_not be_a_kind_of( BaseConfig )

    end

    it 'should instantiate with any input.' do

      [ true, 1, [], 3.0, Object.new, {}, nil ].each do |curr_test_value|
        expect { RunnerPhaseJobConfig.new( curr_test_value ) }.to_not raise_error
      end

    end

    context 'when .validate is called' do

      it 'should ensure nil & non-hash values were not provided during initialization.' do

        # Nil gets a special message.
        expect_validate_to_raise_error( RunnerPhaseJobConfig.new( nil ), 'Provided argument is nil.' )

        # Everything else gets a this-isnt-a-hash message.
        [ 1, [], 3.0, Object.new ].each do |curr_test_value|
          expect_validate_to_raise_error( RunnerPhaseJobConfig.new( curr_test_value ), 'Provided argument is not a hash.' )
        end

      end

      it 'should ensure the required values are all provided' do

        expect { RunnerPhaseJobConfig.new( @all_attributes ).validate }.to_not raise_error

        @all_attributes.keys.each do |curr_key|
          curr_attrs = @all_attributes.dup
          curr_attrs.delete( curr_key )

          expect_validate_to_raise_error( RunnerPhaseJobConfig.new( curr_attrs ), "Key #{ curr_key } missing." )
        end

        expect_validate_to_raise_error( RunnerPhaseJobConfig.new( @empty ), 'Key job_class missing.' )

      end

    end

  end

end
