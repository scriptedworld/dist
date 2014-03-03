
class AssertionFailure < Exception
  # Don't need anything specific, just using it to have a specific thing to raise.
end

def assert( condition, message = nil )
  unless( condition == true )
    usable_message = message || "Condition not met."
    raise AssertionFailure.new( usable_message )
  end
end

def assert_false( condition, message = nil )
  usable_message = message || "Condition is not false."
  assert( ( condition == false ), usable_message )
end

def assert_nil( obj, message = nil )
  usable_message = message || "Object is not nil."
  assert( obj.nil?, usable_message )
end

def assert_not_nil( obj, message = nil )
  usable_message = message || "Object is nil."
  assert( obj.nil? == false, usable_message )
end

def assert_empty( collection, message = nil )
  assert_not_nil( collection )

  usable_message = message || "Collection is not empty."
  assert( collection.empty?, usable_message )
end

def assert_not_empty( collection, message = nil )
  assert_not_nil( collection )

  usable_message = message || "Collection is empty."
  assert( collection.empty? == false, usable_message )
end

def assert_responds_to( obj, method_name, message = nil )
  assert_not_nil( obj )

  usable_message = message || "Provided object does not respond to #{ method_name }."
  assert( obj.respond_t?( method_name.to_sym ), usable_message )
end


