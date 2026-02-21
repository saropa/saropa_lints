// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `prefer_explicit_json_keys` lint rule.

// NOTE: prefer_explicit_json_keys fires on @JsonSerializable classes
// with fields missing @JsonKey(name: ...) annotations.
//
// BAD:
// @JsonSerializable()
// class User { String firstName; } // key derived from field name
//
// GOOD:
// @JsonSerializable()
// class User { @JsonKey(name: 'first_name') String firstName; }

void main() {}
