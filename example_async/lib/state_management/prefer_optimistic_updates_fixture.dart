// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `prefer_optimistic_updates` lint rule.

// NOTE: prefer_optimistic_updates fires on setState() called after
// await in async methods of widget State classes.
// Requires widget State class context.
//
// BAD:
// Future<void> save() async {
//   await api.save(data);
//   setState(() => _saved = true); // slow — user waits
// }
//
// GOOD:
// Future<void> save() async {
//   setState(() => _saved = true); // optimistic — instant feedback
//   await api.save(data);
// }

void main() {}
