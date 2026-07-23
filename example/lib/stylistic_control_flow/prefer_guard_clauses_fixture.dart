// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_identifier, undefined_method, undefined_function

/// Fixture for `prefer_guard_clauses` lint rule.

// BAD: the entire function body is a single `if` that wraps all the work.
// expect_lint: prefer_guard_clauses
void handleBad(int x) {
  if (x > 0) {
    process(x);
  }
}

// GOOD: a guard clause returns early, keeping the happy path un-nested.
void handleGood(int x) {
  if (x <= 0) {
    return;
  }
  process(x);
}
