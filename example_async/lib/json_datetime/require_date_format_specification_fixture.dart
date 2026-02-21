// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `require_date_format_specification` lint rule.

// NOTE: require_date_format_specification fires on DateFormat()
// usage without explicit pattern string.
//
// BAD:
// final fmt = DateFormat(); // uses device locale — inconsistent
//
// GOOD:
// final fmt = DateFormat('yyyy-MM-dd'); // explicit pattern

void main() {}
