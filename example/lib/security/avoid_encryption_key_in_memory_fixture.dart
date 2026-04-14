// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_encryption_key_in_memory` lint rule.

// NOTE: avoid_encryption_key_in_memory fires on field declarations
// with names matching /(encryption|private|secret|aes|rsa|hmac).*key/i.
//
// BAD:
// class Service {
//   final String _encryptionKey = 'abc123'; // stored in memory
// }
//
// GOOD:
// class Service {
//   Future<String> get _key => secureStorage.read('key');
// }

void main() {}
