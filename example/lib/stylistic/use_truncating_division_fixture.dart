// ignore_for_file: unused_local_variable, unused_element
// Test fixture for: use_truncating_division_strict
// Source: lib/src/rules/stylistic/stylistic_rules.dart

// BAD: Should trigger use_truncating_division_strict
void _badUseTruncatingDivision(int total, int size) {
  // expect_lint: use_truncating_division_strict
  final pages = (total / size).toInt();
  print(pages);
}

// GOOD: Should NOT trigger use_truncating_division_strict
void _goodUseTruncatingDivision(int total, int size) {
  final pages = total ~/ size;
  print(pages);
}
