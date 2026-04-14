// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `prefer_secure_random_for_crypto` lint rule.

// NOTE: prefer_secure_random_for_crypto fires on Random() usage
// without .secure() in cryptographic contexts.
//
// BAD:
// final rng = Random(); // predictable RNG for crypto
//
// GOOD:
// final rng = Random.secure(); // cryptographic RNG

void main() {}
