// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `prefer_try_parse_for_dynamic_data` lint rule.

// NOTE: prefer_try_parse_for_dynamic_data fires on .parse() calls
// when .tryParse() is available (int.parse, double.parse, etc.).
//
// BAD:
// final n = int.parse(userInput); // throws on invalid input
//
// GOOD:
// final n = int.tryParse(userInput); // returns null on invalid

void main() {}
