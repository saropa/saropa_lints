// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `avoid_escaping_inner_quotes` lint rule.

// BAD: Escaped inner quotes
// expect_lint: avoid_escaping_inner_quotes
const String bad = "He said \"hello\"";

// GOOD: Other delimiter so no escaping
const String good = 'He said "hello"';

void main() {}
