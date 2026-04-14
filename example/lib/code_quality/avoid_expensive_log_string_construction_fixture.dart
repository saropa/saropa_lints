// ignore_for_file: unused_local_variable, unused_element

import 'dart:developer' as dev;

/// Fixture for `avoid_expensive_log_string_construction` lint rule.

// BAD: Log with string interpolation (built even when level is off)
// expect_lint: avoid_expensive_log_string_construction
void bad(int x) {
  dev.log('value: $x');
}

// GOOD: No interpolation or guard with level
void good(int x) {
  dev.log('value logged');
}

void main() {}
