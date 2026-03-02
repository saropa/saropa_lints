// ignore_for_file: unused_element, unused_local_variable, dead_code
// Compliant-only fixture for behavioral tests: no expect_lint.
// Used to assert "compliant code → no lint" (see fixture_lint_integration_test.dart).

/// Compliant for avoid_catch_all: typed catch with stack.
void compliantCatch() {
  try {
    return;
  } on Object catch (e, st) {
    return;
  }
}

/// Compliant for prefer_specifying_future_value_type: explicit type.
void compliantFuture() {
  final f = Future<int>.value(0);
}

void main() {
  compliantCatch();
  compliantFuture();
}
