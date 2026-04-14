// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_where_or_null` lint rule.

// BAD: Should trigger prefer_where_or_null
// expect_lint: prefer_where_or_null
void _bad247(List<int> items) {
  final x = items.firstWhere((e) => e > 5, orElse: () => -1);
}

// GOOD: Should NOT trigger prefer_where_or_null
void _good247(List<int> items) {
  final x = items.firstWhereOrNull((e) => e > 5) ?? -1;
}

void main() {}
