// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_context_in_async_static` lint rule.

// NOTE: avoid_context_in_async_static fires when an async static
// method takes BuildContext as a parameter.
//
// BAD:
// static Future<void> navigate(BuildContext context) async { ... }
//
// GOOD:
// static Future<void> navigate(GlobalKey<NavigatorState> navKey) async { ... }

void main() {}
