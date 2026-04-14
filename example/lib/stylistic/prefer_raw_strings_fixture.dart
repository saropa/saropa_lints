// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_raw_strings` lint rule.

// BAD: Escaped backslashes (e.g. regex)
// expect_lint: prefer_raw_strings
final String bad = '\\d+';

// GOOD: Raw string
final String good = r'\d+';

void main() {}
