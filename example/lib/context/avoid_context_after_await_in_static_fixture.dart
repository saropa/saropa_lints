// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_context_after_await_in_static` lint rule.

// NOTE: avoid_context_after_await_in_static fires on static async
// methods that use BuildContext after await. Static methods have
// no mounted check and context may be invalid.
//
// BAD:
// static Future<void> show(BuildContext context) async {
//   await prepare();
//   showDialog(context: context, ...); // context may be stale
// }
//
// GOOD:
// static Future<void> show(BuildContext context) async {
//   await prepare();
//   if (context.mounted) showDialog(context: context, ...);
// }

void main() {}
