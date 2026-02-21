// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `no_boolean_literal_compare` lint rule.

// BAD: Should trigger no_boolean_literal_compare
// expect_lint: no_boolean_literal_compare
void _bad(bool isValid) {
  if (isValid == true) {} // Redundant comparison to literal
}

// GOOD: Should NOT trigger no_boolean_literal_compare
void _good(bool isValid) {
  if (isValid) {} // Use boolean value directly
}
