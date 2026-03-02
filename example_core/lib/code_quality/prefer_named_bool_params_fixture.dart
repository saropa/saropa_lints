// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_named_bool_params` lint rule.

// BAD: Positional bool
// expect_lint: prefer_named_bool_params
void bad(bool x) {}

// GOOD: Named bool
void good({required bool x}) {}

void main() {}
