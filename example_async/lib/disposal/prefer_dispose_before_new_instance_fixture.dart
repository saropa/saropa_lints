// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `prefer_dispose_before_new_instance` lint rule.

// NOTE: prefer_dispose_before_new_instance fires in widget/State classes.
// Requires class extending State<T> with controller fields.
//
// BAD:
// // Re-creating controller without disposing old one
//
// GOOD:
// // Dispose old controller before creating new one

void main() {}
