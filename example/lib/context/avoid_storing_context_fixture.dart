// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_storing_context` lint rule.

// NOTE: avoid_storing_context fires on field declarations with
// BuildContext type or assignments of context to fields.
// Requires BuildContext type resolution.
//
// BAD:
// class _Service {
//   late BuildContext _context; // stored context — stale after dispose
// }
//
// GOOD:
// Use context directly in methods, not stored in fields.

void main() {}
