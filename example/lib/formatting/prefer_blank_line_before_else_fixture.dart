// ignore_for_file: unused_element

/// Fixture for `prefer_blank_line_before_else` lint rule.

// BAD: Should trigger prefer_blank_line_before_else
void _bad() {
  final x = true;
  if (x) {
    return;
  } else { // expect_lint: prefer_blank_line_before_else
    return;
  }
}

// GOOD: Should NOT trigger prefer_blank_line_before_else
void _good() {
  final x = true;
  if (x) {
    return;
  }

  else {
    return;
  }
}

// FALSE POSITIVE guard: if without else must NOT trigger (no else clause).
void _noElse() {
  final x = true;
  if (x) {
    return;
  }
  return;
}

// FALSE POSITIVE guard: else-if chains must NOT trigger.
void _elseIfChain() {
  final x = 1;
  if (x == 1) {
    return;
  } else if (x == 2) {
    return;
  } else if (x == 3) {
    return;
  }
}
