// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_hardcoded_encryption_keys` lint rule.

// NOTE: avoid_hardcoded_encryption_keys fires on hardcoded key
// values in Key constructors or .fromUtf8() calls.
//
// BAD:
// final key = Key.fromUtf8('my_secret_key_16'); // hardcoded
//
// GOOD:
// final key = Key.fromSecureRandom(16); // generated at runtime

void main() {}
