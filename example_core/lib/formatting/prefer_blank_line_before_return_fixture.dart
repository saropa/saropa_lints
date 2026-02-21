// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_blank_line_before_return` lint rule.

// BAD: Should trigger prefer_blank_line_before_return
// expect_lint: prefer_blank_line_before_return
int _bad() {
  final x = 1;
  return x; // No blank line before return
}

// GOOD: Should NOT trigger prefer_blank_line_before_return
int _good() {
  final x = 1;

  return x; // Blank line before return
}
