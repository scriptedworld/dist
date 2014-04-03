
require 'spec_helper'
require 'dist/config/runnerconfig'

module Dist

  describe 'Runner Phase Configuration Objects' do

    include Helpers

    before( :all ) do

      @all_attributes_base = Hash.new
      @all_attributes_base[ 'name'        ] = 'Phase One'
      @all_attributes_base[ 'description' ] = 'Junk Phase for Testing'
      @all_attributes_base[ 'jobs'        ] = [
        {
          'job_class' => 'Dist::EmptyJob',
          'per_unit'  => 1,
          'unit'      => 'SECOND'
        }
      ]

      @all_attributes_with_count = @all_attributes_base.dup
      @all_attributes_with_count[ 'total_count' ] = 1

      @all_attributes_with_duration = @all_attributes_base.dup
      @all_attributes_with_duration[ 'phase_duration'       ] = 1
      @all_attributes_with_duration[ 'phase_duration_units' ] = 'SECOND'

      @all_attributes_with_both = @all_attributes_base.dup
      @all_attributes_with_both[ 'total_count'          ] = 1
      @all_attributes_with_both[ 'phase_duration'       ] = 1
      @all_attributes_with_both[ 'phase_duration_units' ] = 'SECOND'

      @empty = {}

    end

    it 'should NOT be derived from BaseConfig' do
      expect( RunnerPhaseConfig.new( {} ) ).to_not be_a_kind_of( BaseConfig )
    end

    it 'should instantiate with any input.' do

      [ true, 1, [], 3.0, Object.new, {} ].each do |curr_test_value|
        expect { RunnerPhaseConfig.new( curr_test_value ) }.to_not raise_error
      end

    end

    context 'when .validate is called' do

      it 'should ensure nil & non-hash values were not provided during initialization.' do

        # Nil gets a special message.
        conf = RunnerPhaseConfig.new( nil )
        expect { conf.validate }.to raise_error( 'Provided argument is nil.' )

        # Everything else gets a this-isnt-a-hash message.
        [ 1, [], 3.0, Object.new ].each do |curr_test_value|
          conf = RunnerPhaseConfig.new( curr_test_value )
          expect { conf.validate }.to raise_error( 'Provided argument is not a hash.' )
        end

      end

      it 'should ensure the required values are all provided' do

        [ @all_attributes_with_count, @all_attributes_with_duration ].each do |curr_attrs|

          conf = RunnerPhaseConfig.new( curr_attrs )
          expect { conf.validate }.to_not raise_error

        end

        [ @all_attributes_with_duration, @all_attributes_with_count ].each do |curr_attr_coll|

          curr_attr_coll.keys.each do |curr_key|
            curr_attrs = curr_attr_coll.dup
            curr_attrs.delete( curr_key )

            expected_message = "Key #{ curr_key } missing."
            expected_message = 'Either total_count or phase_duration must be provided for each phase definition.' if ( curr_key == 'total_count' ) || ( curr_key == 'phase_duration' ) || ( curr_key == 'phase_duration_units' )

            conf = RunnerPhaseConfig.new( curr_attrs )
            expect { conf.validate }.to raise_error( expected_message )
          end

        end

        conf = RunnerPhaseConfig.new( {} )
        expect { conf.validate }.to raise_error( 'Key name missing.' )

      end

      it 'should allow an either-or-both behavior for total_count and phase_duration' do

        conf = RunnerPhaseConfig.new( @all_attributes_with_both )
        expect { conf.validate }.to_not raise_error

      end

      it 'should ignore the phase_duration & phase_duration_units if either are missing' do

        attrs_without_phase_duration = @all_attributes_with_both.dup
        attrs_without_phase_duration.delete( 'phase_duration' )

        conf = RunnerPhaseConfig.new( attrs_without_phase_duration )
        conf.validate
        expect( conf.attributes.keys ).to_not include( 'phase_duration', 'phase_duration_units' )

        attrs_without_phase_duration_units = @all_attributes_with_both.dup
        attrs_without_phase_duration_units.delete( 'phase_duration_units' )

        conf = RunnerPhaseConfig.new( attrs_without_phase_duration_units )
        conf.validate
        expect( conf.attributes.keys ).to_not include( 'phase_duration', 'phase_duration_units' )

      end

      it 'should create and validate a RunnerPhaseJobConfig object for each member of the jobs array.' do
        RunnerPhaseJobConfig.any_instance.should_receive( :validate ).once
        RunnerPhaseConfig.new( @all_attributes_with_count ).validate
      end

    end

  end

end
