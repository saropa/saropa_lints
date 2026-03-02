// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_interpolation_to_compose` lint rule.

// BAD: + concatenation with variable
// expect_lint: prefer_interpolation_to_compose
String bad(String name) => 'Hello, ' + name + '!';

// GOOD: String interpolation
String good(String name) => 'Hello, $name!';

void main() {}
