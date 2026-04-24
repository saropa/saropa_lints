// ignore_for_file: unused_local_variable, unnecessary_nan_comparison
// Test fixture for: prefer_isnan_over_nan_equality
// Source: lib/src/rules/config/sdk_migration_batch2_rules.dart

void badNanCompare(double x) {
  // expect_lint: prefer_isnan_over_nan_equality
  final a = x == double.nan;
  // expect_lint: prefer_isnan_over_nan_equality
  final b = x != double.nan;
  // expect_lint: prefer_isnan_over_nan_equality
  final c = double.nan == x;
}

void goodNanCheck(double x) {
  final a = x.isNaN;
  final b = !x.isNaN;
}
