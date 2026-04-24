// ignore_for_file: unused_local_variable, unused_element
// Test fixture for: avoid_deprecated_use_material3_copy_with
// Source: lib/src/rules/config/migration_rules.dart
// package:flutter/ — rule requires this substring; ThemeData from ../flutter_mocks.dart

import '../flutter_mocks.dart';

// BAD: useMaterial3 in ThemeData.copyWith (misleading; use constructor)
// expect_lint: avoid_deprecated_use_material3_copy_with
void _badCopyWith() {
  ThemeData().copyWith(useMaterial3: false);
}

// GOOD: set in constructor
void _goodCtor() {
  ThemeData(useMaterial3: false);
}
