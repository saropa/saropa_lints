// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: prefer_tabbar_theme_indicator_color
// Test fixture for: prefer_tabbar_theme_indicator_color
// Source: lib\src\rules\config\migration_rules.dart

import '../flutter_mocks.dart';

// BAD: Using deprecated 'indicatorColor' in ThemeData constructor
// expect_lint: prefer_tabbar_theme_indicator_color
ThemeData _badConstructor() {
  return ThemeData(
    indicatorColor: Colors.blue,
  );
}

// BAD: Using deprecated 'indicatorColor' in ThemeData.copyWith
// expect_lint: prefer_tabbar_theme_indicator_color
void _badCopyWith() {
  final theme = ThemeData();
  theme.copyWith(indicatorColor: Colors.blue);
}

// BAD: Reading deprecated 'indicatorColor' property
// expect_lint: prefer_tabbar_theme_indicator_color
void _badPropertyAccess() {
  final theme = ThemeData();
  final color = theme.indicatorColor;
}

// GOOD: Using TabBarThemeData.indicatorColor instead
ThemeData _goodTabBarTheme() {
  return ThemeData(
    tabBarTheme: const TabBarThemeData(
      indicatorColor: Colors.blue,
    ),
  );
}

// GOOD: ThemeData constructor without indicatorColor
ThemeData _goodNoIndicatorColor() {
  return ThemeData(
    primaryColor: Colors.blue,
  );
}

// GOOD: copyWith without indicatorColor
void _goodCopyWithOther() {
  final theme = ThemeData();
  theme.copyWith(primaryColor: Colors.red);
}

// FALSE POSITIVE: indicatorColor on TabBarThemeData is the correct API
void _fpTabBarThemeData() {
  const tabBarTheme = TabBarThemeData(indicatorColor: Colors.blue);
}

// FALSE POSITIVE: Variable named indicatorColor (not ThemeData property)
void _fpLocalVariable() {
  final indicatorColor = Colors.blue;
}
