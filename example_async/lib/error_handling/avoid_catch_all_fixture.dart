// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_catch_all` lint rule.

// BAD: Should trigger avoid_catch_all
void _bad() {
  try {
    doSomething();
    // expect_lint: avoid_catch_all
  } catch (e) {} // bare catch — hides error type
}

// GOOD: Should NOT trigger avoid_catch_all
void _good() {
  try {
    doSomething();
  } on Object catch (e, st) { print(e); } // catches all with type
}

void main() {}
