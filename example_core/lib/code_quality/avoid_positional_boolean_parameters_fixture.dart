// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `avoid_positional_boolean_parameters` lint rule.

// BAD: Positional bool parameter
// expect_lint: avoid_positional_boolean_parameters
void bad(bool enabled) {}

// GOOD: Named bool parameter
void good({required bool enabled}) {}

void main() {}
