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

// BAD: `||` does not guard — the branch still runs under test whenever
// isBreak is true. Only `&&` lets one guarded term cover the condition.
void _bad_orCompoundIsNotAGuard() {
  if (isBreak || !PlatformUtils.isTestEnvironment) {
    // expect_lint: guard_debugger_against_test_environment
    debugger();
  }
}

// BAD: !(A && B) is true under test whenever B is false.
void _bad_negatedAndIsNotAGuard() {
  if (!(PlatformUtils.isTestEnvironment && isBreak)) {
    // expect_lint: guard_debugger_against_test_environment
    debugger();
  }
}

// BAD: a guard clause that falls through guards nothing.
void _bad_guardClauseWithoutBailOut() {
  if (PlatformUtils.isTestEnvironment) {
    isBreak = false;
  }
  // expect_lint: guard_debugger_against_test_environment
  debugger();
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

// GOOD: early-return guard clause — the call is unreachable under test.
void _good_earlyReturnGuardClause() {
  if (PlatformUtils.isTestEnvironment) return;
  debugger();
}

// GOOD: else branch of a POSITIVE check runs only outside the test
// environment (the mirror image of the bad else-branch case above).
void _good_elseBranchOfPositiveCheck() {
  if (PlatformUtils.isTestEnvironment) {
    // skip
  } else {
    debugger();
  }
}

// GOOD: De Morgan — !(isTestEnvironment || x) implies !isTestEnvironment.
void _good_negatedOr() {
  if (!(PlatformUtils.isTestEnvironment || isBreak)) {
    debugger();
  }
}
