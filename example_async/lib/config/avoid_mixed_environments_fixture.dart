// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_mixed_environments` lint rule.

// NOTE: avoid_mixed_environments fires when kDebugMode/kProfileMode
// are used in conditional assignments that mix env configs.
//
// BAD:
// final url = kDebugMode ? 'http://localhost' : prodUrl;
//
// GOOD:
// final url = AppConfig.current.apiUrl; // config-driven

void main() {}
