// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_print_error` lint rule.

// BAD: Should trigger avoid_print_error
void _bad() {
  try {
    doSomething();
  } on Object catch (e) {
    // expect_lint: avoid_print_error
    print(e); // print in catch — invisible to crash reporting
  }
}

// GOOD: Should NOT trigger avoid_print_error
void _good() {
  try {
    doSomething();
  } on Object catch (e, st) {
    logger.error('Failed', error: e, stackTrace: st);
  }
}

void main() {}
