// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `prefer_iso8601_dates` lint rule.

// NOTE: prefer_iso8601_dates fires on non-ISO date formatting
// patterns in string serialization.
//
// BAD:
// final str = '${date.day}/${date.month}/${date.year}'; // ambiguous
//
// GOOD:
// final str = date.toIso8601String(); // ISO 8601 standard

void main() {}
