// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages
// Test fixture for: require_ignore_comment_spacing
// Source: lib\src\rules\stylistic\formatting_rules.dart

// BAD: Should trigger require_ignore_comment_spacing (no space after colon)
// expect_lint: require_ignore_comment_spacing
// ignore:require_debouncer_cancel
void _badIgnoreSpacing() {}

// BAD: ignore_for_file with no space
// expect_lint: require_ignore_comment_spacing
// ignore_for_file:avoid_print
void _badIgnoreForFileSpacing() {}

// GOOD: Should NOT trigger (space after colon)
// ignore: require_debouncer_cancel
void _goodIgnoreSpacing() {}

// GOOD: ignore_for_file with space
// ignore_for_file: avoid_print
void _goodIgnoreForFileSpacing() {}
