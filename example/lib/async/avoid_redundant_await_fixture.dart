// ignore_for_file: unused_local_variable, unused_element

import 'dart:async';

/// Fixture for `avoid_redundant_await` lint rule.

// BAD: Await on non-Future
// expect_lint: avoid_redundant_await
Future<void> bad() async {
  await 1;
  final someInt = 1;
  await someInt;
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
  }) => _inner.catchError(onError, test: test);

  @override
  Future<R> then<R>(
    FutureOr<R> Function(int value) onValue, {
    Function? onError,
  }) => _inner.then(onValue, onError: onError);

  @override
  Future<int> timeout(
    Duration timeLimit, {
    FutureOr<int> Function()? onTimeout,
  }) => _inner.timeout(timeLimit, onTimeout: onTimeout);

  @override
  Future<int> whenComplete(FutureOr<void> Function() action) =>
      _inner.whenComplete(action);
}

// OK: await on a class that implements Future (not the Future type itself).
Future<void> goodImplementsFuture() async {
  final v = await _DelegatingFuture(Future.value(1));
  print(v);
}

class TickerFuture {}

class _DummySimulation {}

class AnimationController {
  TickerFuture forward() => TickerFuture();
  TickerFuture reverse() => TickerFuture();
  TickerFuture animateTo(double target, {Duration? duration}) => TickerFuture();
  TickerFuture animateBack(double target, {Duration? duration}) =>
      TickerFuture();
  TickerFuture animateWith(_DummySimulation simulation) => TickerFuture();
  TickerFuture repeat() => TickerFuture();
  TickerFuture fling() => TickerFuture();
}

// OK: awaiting AnimationController sequencing calls is intentional.
Future<void> goodAnimationControllerAwaits() async {
  final controller = AnimationController();
  await controller.forward();
  await controller.reverse();
  await controller.animateTo(1.0, duration: const Duration(milliseconds: 200));
  await controller.animateBack(0.0);
  await controller.animateWith(_DummySimulation());
  await controller.repeat();
  await controller.fling();
}

// Regression: static methods returning Future<T> must not fire.
// The rule's staticType can fail to resolve for static invocations; the
// fallback through staticInvokeType.returnType must catch these.
class _StaticFutureIO {
  _StaticFutureIO._();
  static Future<String?> loadByKey(String key) async => null;
  static Future<List<int>> loadAll() async => [];
  static Future<bool> update({required String id}) async => true;
  static Future<void> delete(String id) async {}
}

// OK: await on static methods returning Future<T>
Future<void> goodStaticFutureReturning() async {
  final String? a = await _StaticFutureIO.loadByKey('x');
  final List<int> b = await _StaticFutureIO.loadAll();
  final bool c = await _StaticFutureIO.update(id: 'a');
  await _StaticFutureIO.delete('a');
  print('$a $b $c');
}

void main() {}
