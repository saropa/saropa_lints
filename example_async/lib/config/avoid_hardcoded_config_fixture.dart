// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_hardcoded_config` lint rule.

// NOTE: avoid_hardcoded_config fires on hardcoded URL strings
// and API endpoint literals in source code.
//
// BAD:
// final apiUrl = 'https://api.prod.example.com/v1';
//
// GOOD:
// final apiUrl = const String.fromEnvironment('API_URL');

void main() {}
