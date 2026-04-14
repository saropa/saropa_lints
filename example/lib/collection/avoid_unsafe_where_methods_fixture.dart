// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `avoid_unsafe_where_methods` lint rule.

// BAD: Should trigger avoid_unsafe_where_methods
// expect_lint: avoid_unsafe_where_methods
void _bad246(List<int> items) {
  final x = items.firstWhere((e) => e > 5); // No orElse — throws if missing
}

// GOOD: Should NOT trigger avoid_unsafe_where_methods
void _good246(List<int> items) {
  final x = items.firstWhere((e) => e > 5, orElse: () => -1); // Safe
}

void main() {}
