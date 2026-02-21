// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `avoid_unsafe_reduce` lint rule.

// BAD: Should trigger avoid_unsafe_reduce
// expect_lint: avoid_unsafe_reduce
void _bad245() {
  final items = <int>[];
  final sum = items.reduce((a, b) => a + b); // Throws if empty
}

// GOOD: Should NOT trigger avoid_unsafe_reduce
void _good245() {
  final items = <int>[];
  final sum = items.fold(0, (a, b) => a + b); // fold has initial value
}

void main() {}
