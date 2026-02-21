// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `require_structured_logging` lint rule.

// NOTE: require_structured_logging fires on log/print calls using
// string concatenation (+) instead of structured parameters.
//
// BAD:
// log('User ' + user.name + ' logged in'); // concatenation
//
// GOOD:
// log('User logged in', data: {'user': user.name}); // structured

void main() {}
