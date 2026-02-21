// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `require_session_timeout` lint rule.

// NOTE: require_session_timeout fires on sign-in method calls
// without subsequent Timer/timeout setup.
//
// BAD:
// await auth.signIn(email, password); // no session timeout
//
// GOOD:
// await auth.signIn(email, password);
// _sessionTimer = Timer(Duration(hours: 1), _logout);

void main() {}
