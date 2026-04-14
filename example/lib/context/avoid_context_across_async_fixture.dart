// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_context_across_async` lint rule.

// NOTE: avoid_context_across_async fires when BuildContext is used
// after an await — the context may be invalid after async gap.
// Requires BuildContext type resolution.
//
// BAD:
// Future<void> load(BuildContext context) async {
//   await fetchData();
//   Navigator.of(context).push(...); // context may be stale
// }
//
// GOOD:
// Future<void> load(BuildContext context) async {
//   await fetchData();
//   if (context.mounted) Navigator.of(context).push(...);
// }

void main() {}
