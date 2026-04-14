// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_unsafe_deserialization` lint rule.

// NOTE: avoid_unsafe_deserialization fires on jsonDecode() or
// json.decode() calls without type validation on the result.
//
// BAD:
// final data = jsonDecode(input);
// processData(data['value']); // no type check
//
// GOOD:
// final raw = jsonDecode(input);
// if (raw is Map<String, dynamic>) { processData(raw['value']); }

void main() {}
