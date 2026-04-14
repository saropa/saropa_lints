// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `avoid_nested_assignments` lint rule.

dynamic x;

// BAD: Should trigger avoid_nested_assignments
// expect_lint: avoid_nested_assignments
void _bad(dynamic Function() getValue) {
  if ((x = getValue()) != null) {} // Assignment nested inside condition
}

// GOOD: Should NOT trigger avoid_nested_assignments
void _good(dynamic Function() getValue) {
  x = getValue(); // Assignment as standalone statement
  if (x != null) {}
}
