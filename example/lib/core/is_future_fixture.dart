// ignore_for_file: unused_element

/// Fixtures for is_future.
library;

import 'dart:async';

// =============================================================================
// BAD: fragile runtime `is Future` checks used to branch async behavior
// =============================================================================

void handleDynamicResult(dynamic result) {
  // expect_lint: is_future
  if (result is Future) {
    result.then((dynamic value) => print(value));
  } else {
    print(result);
  }
}

void handleNegatedCheck(dynamic result) {
  // expect_lint: is_future
  if (result is! Future) {
    print(result);
  } else {
    result.then((dynamic value) => print(value));
  }
}

void handleTypedFutureCheck(dynamic result) {
  // expect_lint: is_future
  if (result is Future<int>) {
    result.then((int value) => print(value));
  }
}

// =============================================================================
// GOOD: FutureOr<T> + await handles both sync and async cases uniformly
// =============================================================================

Future<void> handleFutureOr(FutureOr<Object?> result) async {
  // Near-miss: FutureOr<T> is NOT a Future — awaiting it directly is the
  // correct, non-fragile way to unify sync and async values.
  final Object? value = await result;
  print(value);
}

void handleUnrelatedTypeCheck(dynamic result) {
  // Near-miss: type-checking against an unrelated type is not what this
  // rule targets.
  if (result is String) {
    print(result);
  }
}
