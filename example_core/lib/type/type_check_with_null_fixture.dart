// Test fixture for: type_check_with_null
// BAD: x is Null / x is! Null triggers the lint.
// GOOD: x == null / x != null does not.

void badIsNull(Object? x) {
  // LINT: type_check_with_null
  if (x is Null) {}
}

void badIsNotNull(Object? x) {
  // LINT: type_check_with_null
  if (x is! Null) {}
}

void goodEqualsNull(Object? x) {
  if (x == null) {}
}

void goodNotEqualsNull(Object? x) {
  if (x != null) {}
}
