// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_adjacent_strings` lint rule.

// BAD: + concatenation of literals
// expect_lint: prefer_adjacent_strings
const String bad = 'Hello' + ' world';

// GOOD: Adjacent string literals
const String good = 'Hello' ' world';

void main() {}
