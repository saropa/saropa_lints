// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_sensitive_data_in_clipboard` lint rule.

// NOTE: avoid_sensitive_data_in_clipboard fires on Clipboard.setData()
// with variable names matching password/token/apiKey/secret patterns.
//
// BAD:
// Clipboard.setData(ClipboardData(text: password));
//
// GOOD:
// Clipboard.setData(ClipboardData(text: shareableLink));

void main() {}
