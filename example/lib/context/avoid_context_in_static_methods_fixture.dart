// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_context_in_static_methods` lint rule.

// NOTE: avoid_context_in_static_methods fires on static methods
// with BuildContext parameter — context has no lifecycle guarantee.
//
// BAD:
// static void show(BuildContext context) { ... }
//
// GOOD:
// void show(BuildContext context) { ... } // instance method

void main() {}
