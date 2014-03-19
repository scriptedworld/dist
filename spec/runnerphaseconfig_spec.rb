require './spec/spec_helper.rb'
require './lib/config/runnerconfig.rb'

describe "Runner Phase Configuration Objects" do

  before( :all ) do

    @all_attributes_base = Hash.new
    @all_attributes_base[ 'name'        ] = 'Phase One'
    @all_attributes_base[ 'description' ] = 'Junk Phase for Testing'
    @all_attributes_base[ 'jobs'        ] = []

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

  it "should NOT be derived from BaseConfig" do

    expect( RunnerPhaseConfig.new( {} ) ).to_not be_a_kind_of( BaseConfig )

  end

  it "should instantiate with any input." do

    [ true, 1, [], 3.0, Object.new, {}, nil ].each do |curr_test_value|
      expect { 
        RunnerPhaseConfig.new( curr_test_value ) 
      }.to_not raise_error()
    end

  end

  context 'when .validate() is called' do

    it "should ensure nil & non-hash values weren't provided during initialization." do

      # Nil gets a special message.
      expect {
        RunnerPhaseConfig.new( nil ).validate()
      }.to raise_error( "Provided argument is nil." )

      # Everything else gets a this-isnt-a-hash message.
      [ 1, [], 3.0, Object.new ].each do |curr_test_value|
        expect {
          RunnerPhaseConfig.new( curr_test_value ).validate()
        }.to raise_error( "Provided argument is not a hash." )
      end

    end

    it "should ensure the required values are all provided" do

      [ @all_attributes_with_count, @all_attributes_with_duration ].each do |curr_attrs|
        expect {
          RunnerPhaseConfig.new( curr_attrs ).validate()
        }.to_not raise_error()
      end

      # TODO: Need to add code here to iterate through the keys provided

      expect {
        RunnerPhaseConfig.new( @empty ).validate()
      }.to raise_error( 'Key name missing.' )

    end

    it "should allow an either-or-both behavior for total_count and phase_duration" do

      expect {
        RunnerPhaseConfig.new( @all_attributes_with_both ).validate()
      }.to_not raise_error()

      expect {
        RunnerPhaseConfig.new( @all_attributes_base ).validate()
      }.to raise_error( 'Either total_count or phase_duration must be provided for each phase definition.' )

    end

  end

end
