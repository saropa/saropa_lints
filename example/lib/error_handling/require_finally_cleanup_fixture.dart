// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `require_finally_cleanup` lint rule.

// NOTE: require_finally_cleanup fires on try-finally blocks that
// do not dispose resources allocated in the try body.
//
// BAD:
// final controller = TextEditingController();
// try { ... } finally { } // no cleanup
//
// GOOD:
// final controller = TextEditingController();
// try { ... } finally { controller.dispose(); }

void main() {}
