// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_switch_expression` lint rule.

// BAD: Should trigger prefer_switch_expression
// expect_lint: prefer_switch_expression
String _bad(int x) {
  switch (x) {
    // All cases return — use switch expression
    case 1:
      return 'one';
    case 2:
      return 'two';
    default:
      return 'other';
  }
}

// GOOD: Should NOT trigger prefer_switch_expression
String _good(int x) => switch (x) {
      // Switch expression
      1 => 'one',
      2 => 'two',
      _ => 'other',
    };
