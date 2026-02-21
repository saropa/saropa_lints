// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `avoid_variable_shadowing` lint rule.

// BAD: Should trigger avoid_variable_shadowing
void _bad(int x) {
  // expect_lint: avoid_variable_shadowing
  final x = 2; // 'x' shadows the parameter 'x'
}

// GOOD: Should NOT trigger avoid_variable_shadowing
void _good(int x) {
  final y = x + 1; // different name — no shadowing
}

void main() {}
