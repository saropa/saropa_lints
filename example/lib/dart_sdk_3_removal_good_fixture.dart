// ignore_for_file: unused_element, unused_local_variable
//
// GOOD / non-violation patterns for dart_sdk_3_removal_rules.dart
// (no expect_lint markers — these must not match the removed-API rules.)

library dart_sdk_3_removal_good_fixture;

void goodListFactories() {
  final a = List<int>.filled(3, 0);
  final b = List<int>.generate(3, (i) => i);
  final c = List<int>.from([1, 2]);
  final d = <int>[];
}

void goodNoSuchMethod() {
  throw NoSuchMethodError.withInvocation(
    Object(),
    Invocation.method(#m, const []),
  );
}

void goodTypeError(Object o) {
  if (o is! int) {
    throw TypeError();
  }
}

/// User-defined [CastError] must not be flagged as the removed dart:core type.
class CastError implements Error {
  @override
  StackTrace? get stackTrace => null;
}

void goodUserCastError(CastError e) {}

/// User-defined [DeferredLibrary] must not be flagged.
class DeferredLibrary {
  const DeferredLibrary(String _);
}

void goodUserDeferredLibrary() {
  const DeferredLibrary('x');
}

class Provisional {
  const Provisional();
}

// User @Provisional() is a different class — not the removed dart:core annotation.
@Provisional()
class _Holder {}

// User types named like removed dart:developer metrics APIs must not match.
class Metrics {
  void record() {}
}

class Metric {
  void m() {}
}

class Counter {
  int get n => 0;
}

class Gauge<T> {
  T? v;
}

void goodUserDeveloperNames(Metrics a, Metric b, Counter c, Gauge<int> g) {
  a.record();
  b.m();
  c.n;
  g.v;
}

/// Local [NetworkInterface] is not dart:io's class.
class NetworkInterface {
  static bool get listSupported => false;
}

void goodUserNetworkInterface() {
  final _ = NetworkInterface.listSupported;
}

// User [HasNextIterator] is not dart:collection's adapter.
class HasNextIterator {
  const HasNextIterator();
}

void goodUserHasNextIterator(HasNextIterator h) {
  final _ = h;
}

// User [NullThrownError] is not dart:core's removed type.
class NullThrownError implements Error {
  @override
  StackTrace? get stackTrace => null;
}

void goodUserNullThrownError(NullThrownError e) {}
