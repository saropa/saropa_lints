// Fixture to test quick fixes for debug print rules.
//
// Quick fix available: "Comment out debugPrint statement"
// Quick fix available: "Comment out print statement"

// ignore_for_file: unused_local_variable

void debugPrintExample() {
  final value = 42;

  // expect_lint: avoid_debug_print
  debugPrint('Debug value: $value');

  // expect_lint: avoid_print_in_production
  print('Production print: $value');
}

void alreadyFixed() {
  final value = 42;

  // Commented out by quick fix - preserves developer intent
  // debugPrint('Debug value: $value');

  // Commented out by quick fix - preserves developer intent
  // print('Production print: $value');
}

// =============================================================================
// Logging Rules (from v4.1.6)
// =============================================================================

// BAD: print without kDebugMode check
void testPrintInRelease() {
  // expect_lint: avoid_print_in_release
  print('This runs in release builds!');
}

// GOOD: print with kDebugMode check
void testPrintWithDebugMode() {
  if (kDebugMode) {
    print('Only runs in debug mode');
  }
}

// BAD: String concatenation in logs
void testStructuredLogging(String user, DateTime time) {
  // expect_lint: require_structured_logging
  print('User ' + user + ' logged in at ' + time.toString());
}

// GOOD: String interpolation instead
void testGoodLogging(String user, DateTime time) {
  if (kDebugMode) {
    print('User $user logged in at $time');
  }
}

// BAD: Sensitive data in logs
void testSensitiveInLogs(String password, String apiKey) {
  // expect_lint: avoid_sensitive_in_logs
  print('Login with password: $password');

  // expect_lint: avoid_sensitive_in_logs
  debugPrint('Using API key: $apiKey');
}

// GOOD: No sensitive data in logs
void testGoodSecureLogs(String userId) {
  if (kDebugMode) {
    print('Login attempt for user: $userId');
  }
}

const bool kDebugMode = true;
