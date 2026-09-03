// ignore_for_file: unused_element

/// Fixture for `prefer_blank_line_before_break` lint rule.

// BAD: Should trigger prefer_blank_line_before_break
void _bad() {
  switch (2) {
    case 1:
      break;
    case 2:
      _doSomething();
      break; // expect_lint: prefer_blank_line_before_break
  }
}

// GOOD: Should NOT trigger prefer_blank_line_before_break
void _good() {
  switch (2) {
    case 2:
      _doSomething();

      break;
  }
}

void _doSomething() {}

// FALSE POSITIVE guard: break as the sole statement in a loop body must NOT
// trigger — there is no preceding sibling statement to separate from.
void _soleBreak() {
  for (var i = 0; i < 10; i++) {
    break;
  }
}
