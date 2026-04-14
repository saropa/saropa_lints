// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_secure_storage_large_data` lint rule.

// NOTE: avoid_secure_storage_large_data fires on write() calls
// to FlutterSecureStorage with large data payloads.
//
// BAD:
// await secureStorage.write(key: 'data', value: largeJsonString);
//
// GOOD:
// await secureStorage.write(key: 'token', value: shortToken);

void main() {}
