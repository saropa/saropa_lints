// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_optional_field_crash` lint rule.

// NOTE: avoid_optional_field_crash fires on Map access without
// null checking on optional fields from JSON.
//
// BAD:
// final name = json['name'] as String; // crash if missing
//
// GOOD:
// final name = json['name'] as String?; // null-safe

void main() {}
