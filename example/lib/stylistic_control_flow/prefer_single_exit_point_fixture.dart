// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_single_exit_point` lint rule.

// BAD: multiple return statements, with an early return inside an `if`.
// expect_lint: prefer_single_exit_point
int classifyBad(int x) {
  if (x > 0) {
    return 1;
  }
  return 2;
}

// GOOD: a single exit point at the end of the function.
int classifyGood(int x) {
  int result;
  if (x > 0) {
    result = 1;
  } else {
    result = 2;
  }
  return result;
}
