// ignore_for_file: unused_element

/// Fixture for `prefer_blank_line_after_loop` lint rule.

// BAD: Should trigger prefer_blank_line_after_loop
void _bad() {
  for (var i = 0; i < 3; i++) {
    print(i);
  }
  doNext(); // expect_lint: prefer_blank_line_after_loop
}

void doNext() {}

// GOOD: Should NOT trigger prefer_blank_line_after_loop
void _good() {
  for (var i = 0; i < 3; i++) {
    print(i);
  }

  doNext();
}

// FALSE POSITIVE guard: block with only a loop (no next statement) must NOT trigger.
void _onlyLoop() {
  for (var i = 0; i < 3; i++) {
    print(i);
  }
}
