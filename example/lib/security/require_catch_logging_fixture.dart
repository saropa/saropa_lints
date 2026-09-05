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

// Undefined-by-design stand-ins for the fixture bodies below; only their
// shape (throws / returns / accepts) matters for exercising the rule, not
// their real implementation.
dynamic riskyCheck() => null;
void showStatus(String message) {}
void processFile(String path) {}

// BAD: catch neither logs, rethrows, nor responds via control flow -- the
// failure vanishes with only a UI side effect to show for it.
// expect_lint: require_catch_logging
void _bad600() {
  try {
    riskyCheck();
  } catch (e) {
    showStatus('failed');
  }
}

// GOOD: catch returns a fallback value. The caller still gets a safe
// result, so this is an intentional "degrade gracefully" response to the
// exception -- not a silent swallow. Mirrors the analyzer-version-probe
// pattern from bugs/require_catch_logging_false_positive_intentional_fallback.md.
dynamic _good600Return() {
  try {
    return riskyCheck();
  } on StateError {
    return false; // Documented fallback when the probe is unsupported.
  }
}

// GOOD: catch continues the loop. The bad item is skipped and the walk
// proceeds with the rest of the list, so the exception is handled via
// control flow, not dropped silently. Mirrors the skip-and-continue file
// walk pattern from the bug report.
void _good600Continue(List<String> files) {
  for (final file in files) {
    try {
      processFile(file);
    } on Exception {
      continue; // Permission denied or file vanished mid-walk -- skip it.
    }
  }
}

// GOOD: catch breaks out of the loop. Stopping the walk on the first
// failure is a deliberate, controlled response to the exception, not a
// silent swallow.
void _good600Break(List<String> files) {
  for (final file in files) {
    try {
      processFile(file);
    } on Exception {
      break; // Abort the walk entirely once one file fails to process.
    }
  }
}

void main() {}
