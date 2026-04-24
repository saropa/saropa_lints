// ignore_for_file: unused_local_variable, unused_element
// Test fixture for: prefer_overflow_bar_over_button_bar
// Source: lib/src/rules/config/migration_rules.dart
// package:flutter/ — rule requires this substring; widgets are mocked in ../flutter_mocks.dart

import '../flutter_mocks.dart';

// BAD: ButtonBar is deprecated
// expect_lint: prefer_overflow_bar_over_button_bar
void _badButtonBar() {
  const ButtonBar();
}

// BAD: ButtonBarThemeData
// expect_lint: prefer_overflow_bar_over_button_bar
void _badButtonBarThemeData() {
  const ButtonBarThemeData();
}

// BAD: ThemeData with buttonBarTheme
// expect_lint: prefer_overflow_bar_over_button_bar
void _badThemeData() {
  ThemeData(buttonBarTheme: ButtonBarThemeData());
}

// GOOD: prefer OverflowBar
void _goodOverflow() {
  const OverflowBar();
}

// GOOD: ThemeData without button bar theme
void _goodTheme() {
  ThemeData();
}
