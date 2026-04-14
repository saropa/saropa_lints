// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_sensitive_in_logs` lint rule.

// NOTE: avoid_sensitive_in_logs fires on log/print calls that include
// variables with sensitive names (password, token, apiKey, etc.).
//
// BAD:
// print('Login: $password'); // leaks password in logs
//
// GOOD:
// print('Login attempted for: $username'); // non-sensitive data

void main() {}
