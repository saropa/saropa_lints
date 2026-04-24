// ignore_for_file: unused_local_variable
// Test fixture for: prefer_code_unit_at
// Source: lib/src/rules/config/sdk_migration_batch2_rules.dart

void badCodeUnits(String s) {
  // expect_lint: prefer_code_unit_at
  final c = s.codeUnits[0];
}

void goodCodeUnitAt(String s) {
  final c = s.codeUnitAt(0);
}
