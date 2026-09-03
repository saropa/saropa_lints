// ignore_for_file: unused_element

/// Fixture for `prefer_blank_line_before_continue` lint rule.

// BAD: Should trigger prefer_blank_line_before_continue
void _bad(List<int> items) {
  for (final item in items) {
    if (item < 0) {
      _log(item);
      continue; // expect_lint: prefer_blank_line_before_continue
    }
  }
}

// GOOD: Should NOT trigger prefer_blank_line_before_continue
void _good(List<int> items) {
  for (final item in items) {
    if (item < 0) {
      _log(item);

      continue;
    }
  }
}

void _log(Object? value) {}

// FALSE POSITIVE guard: continue as the sole statement in a guard clause
// must NOT trigger — there is no preceding sibling statement.
void _soleContinue(List<int> items) {
  for (final item in items) {
    if (item < 0) continue;
  }
}
