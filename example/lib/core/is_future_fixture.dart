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

void handleNullableFutureCheck(dynamic result) {
  // isDartAsyncFuture is true for the nullable form Future<T>? too, so this
  // is just as fragile as the non-nullable check and must still be flagged.
  // expect_lint: is_future
  if (result is Future<int>?) {
    result?.then((int value) => print(value));
  }
}

// A custom class that extends Future — used below to document that checking
// against it is intentionally OUT of scope for this rule (see the "Scope
// note" in is_future_rules.dart's class DartDoc: only the literal `Future`
// annotation is matched, supertypes are not walked).
class CustomFuture<T> extends Future<T> {
  @override
  Stream<T> asStream() => throw UnimplementedError();

  @override
  Future<T> catchError(Function onError, {bool Function(Object)? test}) =>
      throw UnimplementedError();

  @override
  Future<R> then<R>(FutureOr<R> Function(T) onValue, {Function? onError}) =>
      throw UnimplementedError();

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) =>
      throw UnimplementedError();

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) =>
      throw UnimplementedError();
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

void handleCustomFutureSubclassCheck(dynamic result) {
  // Out of scope by design: this rule only matches the literal `Future`
  // annotation and does not walk supertypes, so a custom Future subclass
  // written by the author is not flagged (see the class DartDoc's "Scope
  // note" in is_future_rules.dart for why).
  if (result is CustomFuture) {
    print(result);
  }
}
