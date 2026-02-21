// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_not_encodable_in_to_json` lint rule.

// NOTE: avoid_not_encodable_in_to_json fires on DateTime, Map, or
// complex types returned from toJson() methods.
//
// BAD:
// Map<String, dynamic> toJson() => {'date': createdAt}; // DateTime
//
// GOOD:
// Map<String, dynamic> toJson() => {'date': createdAt.toIso8601String()};

void main() {}
