// Test fixture for: avoid_unnecessary_null_aware_elements
// BAD: ...? when list is non-null
// expect_lint: avoid_unnecessary_null_aware_elements
void bad() {
  final list = <int>[1, 2];
  final out = [0, ...?list];
}

// GOOD: ... when list is non-null
void good() {
  final list = <int>[1, 2];
  final out = [0, ...list];
}
