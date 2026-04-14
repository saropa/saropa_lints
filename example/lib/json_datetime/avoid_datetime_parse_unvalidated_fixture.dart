// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_datetime_parse_unvalidated` lint rule.

// NOTE: avoid_datetime_parse_unvalidated fires on DateTime.parse()
// calls on user input without surrounding try-catch.
// Requires static type analysis for DateTime.parse resolution.
//
// BAD:
// final date = DateTime.parse(userInput); // crashes on bad input
//
// GOOD:
// final date = DateTime.tryParse(userInput); // returns null on bad input

void main() {}
