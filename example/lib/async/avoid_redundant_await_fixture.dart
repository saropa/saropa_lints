// ignore_for_file: unused_local_variable, unused_element

import 'dart:async';

/// Fixture for `avoid_redundant_await` lint rule.

// BAD: Await on non-Future
// expect_lint: avoid_redundant_await
Future<void> bad() async {
  await 1;
}

// GOOD: Await only on Future
Future<void> good() async {
  await Future.value(1);
}

/// Regression: static type `implements Future<T>` but not spelled `Future<…>`
/// (Postgrest-style). Await must not be reported as redundant.
class _DelegatingFuture implements Future<int> {
  _DelegatingFuture(this._inner);
  final Future<int> _inner;

  @override
  Stream<int> asStream() => _inner.asStream();

  @override
  Future<int> catchError(
    Function onError, {
    bool Function(Object error)? test,
  }) =>
      _inner.catchError(onError, test: test);

  @override
  Future<R> then<R>(
    FutureOr<R> Function(int value) onValue, {
    Function? onError,
  }) =>
      _inner.then(onValue, onError: onError);

  @override
  Future<int> timeout(
    Duration timeLimit, {
    FutureOr<int> Function()? onTimeout,
  }) =>
      _inner.timeout(timeLimit, onTimeout: onTimeout);

  @override
  Future<int> whenComplete(FutureOr<void> Function() action) =>
      _inner.whenComplete(action);
}

// OK: await on a class that implements Future (not the Future type itself).
Future<void> goodImplementsFuture() async {
  final v = await _DelegatingFuture(Future.value(1));
  print(v);
}

void main() {}
