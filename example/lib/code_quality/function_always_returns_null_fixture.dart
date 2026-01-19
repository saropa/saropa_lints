// ignore_for_file: unused_local_variable, unused_element, prefer_void_to_null
// Test fixture for function_always_returns_null rule

import 'dart:async';

// =========================================================================
// BAD: Functions that always return null (should be flagged)
// =========================================================================

// expect_lint: function_always_returns_null
String? alwaysReturnsNull() {
  return null;
}

// expect_lint: function_always_returns_null
int? alwaysReturnsNullConditional(bool condition) {
  if (condition) return null;
  return null;
}

// expect_lint: function_always_returns_null
double? expressionBodyNull() => null;

class BadMethods {
  // expect_lint: function_always_returns_null
  String? getValue() {
    return null;
  }

  // expect_lint: function_always_returns_null
  int? getNumber(bool flag) {
    if (flag) {
      return null;
    }
    return null;
  }
}

// =========================================================================
// GOOD: Functions that should NOT be flagged
// =========================================================================

// Void functions with early exit - should NOT be flagged
void voidWithEarlyReturn(bool condition) {
  if (!condition) return; // Early exit is fine
  doSomething();
}

// Future<void> with early exit - should NOT be flagged
Future<void> asyncVoidWithEarlyReturn(bool mounted) async {
  if (!mounted) return; // Early exit is fine in async void
  await doAsyncWork();
}

// FutureOr<void> with early exit - should NOT be flagged
FutureOr<void> futureOrVoidWithEarlyReturn(bool condition) async {
  if (!condition) return;
  doSomething();
}

// No explicit return type, all bare returns - should NOT be flagged (inferred void)
_helperWithBareReturn(bool condition) {
  if (!condition) return;
  doSomething();
}

// Function that returns meaningful values - should NOT be flagged
String? getValueSometimes(bool condition) {
  if (condition) return 'value';
  return null;
}

// Function with no return statements - should NOT be flagged
void noReturnStatements() {
  doSomething();
}

// Type alias for Future<void> - should NOT be flagged
typedef VoidFuture = Future<void>;
VoidFuture typeAliasVoid() async {
  return;
}

// =========================================================================
// Edge cases
// =========================================================================

// Mixed bare and null returns with no explicit type - should be flagged
// because it has explicit `return null;`
// expect_lint: function_always_returns_null
_mixedReturnsWithExplicitNull(bool condition) {
  if (condition) return;
  return null; // Explicit null return makes this suspicious
}

// Nested function should be analyzed separately
void outerFunction() {
  // expect_lint: function_always_returns_null
  String? innerAlwaysNull() {
    return null;
  }

  // This inner void function should NOT be flagged
  void innerVoid() {
    return;
  }
}

// =========================================================================
// Mock functions
// =========================================================================

void doSomething() {}
Future<void> doAsyncWork() async {}
