// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `require_secure_storage_error_handling` lint rule.

// NOTE: require_secure_storage_error_handling fires on secure storage
// method calls (read/write/delete) not wrapped in try-catch.
//
// BAD:
// final token = await secureStorage.read(key: 'token');
//
// GOOD:
// try {
//   final token = await secureStorage.read(key: 'token');
// } on PlatformException catch (e) { handleError(e); }

void main() {}
