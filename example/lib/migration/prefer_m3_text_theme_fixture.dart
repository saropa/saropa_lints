// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: prefer_m3_text_theme
// Test fixture for: prefer_m3_text_theme
// Source: lib\src\rules\config\migration_rules.dart

import '../flutter_mocks.dart';

// BAD: Using deprecated 'headline1' in TextTheme constructor
// expect_lint: prefer_m3_text_theme
void _badConstructorHeadline1() {
  const TextTheme(headline1: null);
}

// BAD: Using deprecated 'bodyText2' in TextTheme constructor
// expect_lint: prefer_m3_text_theme
void _badConstructorBodyText2() {
  const TextTheme(bodyText2: null);
}

// BAD: Using deprecated 'caption' in TextTheme constructor
// expect_lint: prefer_m3_text_theme
void _badConstructorCaption() {
  const TextTheme(caption: null);
}

// BAD: Using deprecated 'button' in TextTheme constructor
// expect_lint: prefer_m3_text_theme
void _badConstructorButton() {
  const TextTheme(button: null);
}

// BAD: Using deprecated 'overline' in TextTheme constructor
// expect_lint: prefer_m3_text_theme
void _badConstructorOverline() {
  const TextTheme(overline: null);
}

// BAD: Using deprecated property access on TextTheme
// expect_lint: prefer_m3_text_theme
void _badPropertyAccess() {
  final theme = ThemeData();
  final style = theme.textTheme.headline1;
}

// BAD: Using deprecated name in copyWith
// expect_lint: prefer_m3_text_theme
void _badCopyWith() {
  const TextTheme().copyWith(subtitle1: null);
}

// GOOD: Using M3 name in constructor
void _goodConstructor() {
  const TextTheme(displayLarge: null);
}

// GOOD: Using M3 name in property access
void _goodPropertyAccess() {
  final theme = ThemeData();
  final style = theme.textTheme.displayLarge;
}

// GOOD: Using M3 name in copyWith
void _goodCopyWith() {
  const TextTheme().copyWith(bodyMedium: null);
}

// FALSE POSITIVE: 'headline1' on a non-TextTheme type
void _fpOtherType() {
  final map = {'headline1': 'value'};
}

// FALSE POSITIVE: 'caption' on a non-TextTheme type
void _fpCaptionOther() {
  final caption = 'Photo caption';
}
