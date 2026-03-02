// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `avoid_riverpod_string_provider_name` lint rule.

// BAD: String literal as provider name
// expect_lint: avoid_riverpod_string_provider_name
final bad = Provider((ref) => 0); // use named provider

// GOOD: Named provider
final good = Provider<int>((ref) => 0);

void main() {}
