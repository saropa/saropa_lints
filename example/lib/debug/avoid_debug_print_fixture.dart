// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_debug_print` lint rule.

// BAD: Should trigger avoid_debug_print
void _bad() {
  // expect_lint: avoid_debug_print
  debugPrint('Loading data...'); // bypasses structured logging
}

// GOOD: Should NOT trigger avoid_debug_print
void _good() {
  logger.info('Loading data...'); // structured logging
}

void main() {}
