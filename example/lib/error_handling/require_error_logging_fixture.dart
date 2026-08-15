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

void debug(String message, {int? level}) {}

Future<void> initFirebase() async {
  try {
    await Future<void>.delayed(const Duration(seconds: 5));
  } on TimeoutException {
    // GOOD — no captured exception parameter, but the body logs a static
    // message via a recognized logging call. Capture is not required for
    // compliance: only absence of any logging call is a violation.
    debug('Firebase initialization timed out - continuing without it');
  }
}

Future<void> unrelatedNoCapture() async {
  try {
    await Future<void>.delayed(const Duration(seconds: 5));
  }
  // expect_lint: require_error_logging
  on TimeoutException {
    doSomethingUnrelated();
  }
}

void doSomethingUnrelated() {}

class TimeoutException implements Exception {}

void main() {}
