// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_print_in_release` lint rule.

// BAD: Should trigger avoid_print_in_release
void _bad() {
  // expect_lint: avoid_print_in_release
  print('Debug info'); // unguarded print in release build
}

// GOOD: Should NOT trigger avoid_print_in_release
void _good() {
  if (kDebugMode) {
    print('Debug info'); // guarded by debug check
  }
}

void main() {}
