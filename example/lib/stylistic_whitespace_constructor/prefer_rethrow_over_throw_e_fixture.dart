// ignore_for_file: unused_element

/// Fixture for `prefer_rethrow_over_throw_e`.

void badCatch() {
  try {
    throw StateError('x');
  } catch (e) {
    // LINT: throw e resets stack trace
    throw e;
  }
}

void goodCatch() {
  try {
    throw StateError('x');
  } catch (e) {
    rethrow;
  }
}
