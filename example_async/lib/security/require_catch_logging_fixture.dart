// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `require_catch_logging` lint rule.

// NOTE: require_catch_logging fires on catch blocks without
// logging or rethrow statements.
//
// BAD:
// try { ... } catch (e) { } // silently swallowed
//
// GOOD:
// try { ... } catch (e, st) { logger.error(e, stackTrace: st); }

void main() {}
