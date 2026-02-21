// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `require_cache_key_determinism` lint rule.

// NOTE: require_cache_key_determinism fires when cache keys use
// non-deterministic values (DateTime.now, Random, hashCode).
// Requires string interpolation with specific patterns.
//
// BAD:
// final key = 'user_${DateTime.now().millisecondsSinceEpoch}';
//
// GOOD:
// final key = 'user_$userId';

void main() {}
