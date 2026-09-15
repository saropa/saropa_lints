// Test fixture for: guard_debugger_against_test_environment
// Source: lib/src/rules/testing/debug_rules.dart

import 'dart:developer';
import 'dart:io';

/// Stand-in for a consumer's own test-environment check — the rule matches
/// this by SHAPE (any identifier containing `isTestEnvironment`), not by
/// this exact class name.
class PlatformUtils {
  static bool isTestEnvironment = false;
}

bool isBreak = false;

// BAD: bare debugger() call, no guard at all.
void _bad_bareDebugger() {
  // expect_lint: guard_debugger_against_test_environment
  debugger();
}

// BAD: kDebugMode is NOT a test-environment guard — flutter test runs in
// debug mode too, so this still hangs the test run.
const bool kDebugMode = true;

void _bad_kDebugModeDoesNotHelp() {
  if (kDebugMode) {
    // expect_lint: guard_debugger_against_test_environment
    debugger();
  }
}

// BAD: debugger() in the else branch of a negated guard — this runs
// exactly when isTestEnvironment IS true, the opposite of guarded.
void _bad_elseBranchOfNegatedGuard() {
  if (!PlatformUtils.isTestEnvironment) {
    // safe path
  } else {
    // expect_lint: guard_debugger_against_test_environment
    debugger();
  }
}

// GOOD: direct negated guard.
void _good_directGuard() {
  if (!PlatformUtils.isTestEnvironment) {
    debugger();
  }
}

// GOOD: compound condition — negated guard is one term of a `&&`.
void _good_compoundGuard() {
  if (isBreak && !PlatformUtils.isTestEnvironment) {
    debugger();
  }
}

// GOOD: inline FLUTTER_TEST environment-variable check.
void _good_flutterTestEnvVar() {
  if (!Platform.environment.containsKey('FLUTTER_TEST')) {
    debugger();
  }
}

// GOOD: guard higher up the lexical chain than the immediate parent.
void _good_guardUpTheChain() {
  if (!PlatformUtils.isTestEnvironment) {
    if (isBreak) {
      debugger();
    }
  }
}
