// ignore_for_file: unused_local_variable, unused_element, dead_code
// Test fixture for: require_exhaustive_sealed_switch (same logic as avoid_wildcard_cases_with_sealed_classes)

sealed class _Shape {}

class _Circle extends _Shape {}

class _Square extends _Shape {}

// BAD: default case on sealed type — expect_lint: require_exhaustive_sealed_switch
double _badArea(_Shape shape) {
  return switch (shape) {
    _Circle() => 0,
    _Square() => 0,
    _ => 0, // LINT: wildcard defeats exhaustiveness
  };
}

// GOOD: explicit cases only
double _goodArea(_Shape shape) {
  return switch (shape) {
    _Circle() => 0,
    _Square() => 0,
  };
}
