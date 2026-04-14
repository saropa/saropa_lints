// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_capitalized_comment_start` lint rule.

// BAD: Should trigger prefer_capitalized_comment_start
// expect_lint: prefer_capitalized_comment_start
// this comment starts with a lowercase letter
void _bad() {}

// GOOD: Should NOT trigger prefer_capitalized_comment_start
// This comment starts with an uppercase letter
void _good() {}
