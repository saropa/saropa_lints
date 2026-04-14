// ignore_for_file: unused_local_variable, unused_element
// Test fixture for: use_truncating_division
// Source: lib/src/rules/stylistic/stylistic_rules.dart

// BAD: Should trigger use_truncating_division
void _badUseTruncatingDivision(int total, int size) {
  // expect_lint: use_truncating_division
  final pages = (total / size).toInt();
  print(pages);
}

// GOOD: Should NOT trigger use_truncating_division
void _goodUseTruncatingDivision(int total, int size) {
  final pages = total ~/ size;
  print(pages);
}
