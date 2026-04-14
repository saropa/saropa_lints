// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_returning_conditional_expressions` lint rule.

// BAD: Should trigger prefer_returning_conditional_expressions
// expect_lint: prefer_returning_conditional_expressions
String _bad(bool flag) {
  if (flag) {
    return 'yes';
  } else {
    return 'no'; // Both branches return — simplify to ternary
  }
}

// GOOD: Should NOT trigger prefer_returning_conditional_expressions
String _good(bool flag) => flag ? 'yes' : 'no'; // Concise ternary return
