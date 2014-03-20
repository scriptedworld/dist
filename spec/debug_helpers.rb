
module DebugHelpers

  def presetDebugStateAndValidateResult( pre_debug_state, expected_debug_state, &block )

    old_state = $DEBUG
    $DEBUG = pre_debug_state

    yield

    result = ( $DEBUG == expected_debug_state )

    $DEBUG = old_state

    result

  end

  def testDebugState( before_state, after_state, config_file_path, config_class = BaseConfig )
    expect {
      presetDebugStateAndValidateResult( before_state, after_state ) do
        config_class.new( config_file_path )
      end
    }.to be_true
  end

end
