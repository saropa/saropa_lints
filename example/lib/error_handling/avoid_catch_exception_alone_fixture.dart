// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_catch_exception_alone` lint rule.

// BAD: Should trigger avoid_catch_exception_alone
void _bad() {
  try {
    doSomething();
    // expect_lint: avoid_catch_exception_alone
  } on Exception catch (e) {} // misses Error types
}

// GOOD: Should NOT trigger avoid_catch_exception_alone
void _good() {
  try {
    doSomething();
  } on Exception catch (e) {
    print(e);
  } on Object catch (e, st) {
    print(e);
  } // fallback for Error types
}

void main() {}
