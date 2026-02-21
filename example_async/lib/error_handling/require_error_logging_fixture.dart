// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `require_error_logging` lint rule.

// NOTE: require_error_logging fires on catch blocks without any
// logging or error tracking calls. Requires analysis of catch body
// for method calls matching logging patterns.
//
// BAD:
// try { ... } on Exception catch (e) { } // empty — error lost
//
// GOOD:
// try { ... } on Exception catch (e, st) {
//   logger.error(e, stackTrace: st);
// }

void main() {}
