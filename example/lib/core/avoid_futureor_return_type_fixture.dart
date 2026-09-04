// ignore_for_file: unused_element

import 'dart:async';

/// Fixtures for avoid_futureor_return_type.
library;

// =============================================================================
// BAD: FutureOr<T> declared as a function/method/getter return type
// =============================================================================

// expect_lint: avoid_futureor_return_type
FutureOr<int> _getValueTopLevel() => 42;

class _Repository {
  // expect_lint: avoid_futureor_return_type
  FutureOr<String> fetchName() => 'saropa';

  // expect_lint: avoid_futureor_return_type
  FutureOr<int> get cachedCount => 3;
}

// =============================================================================
// GOOD: a plain Future<T> return type — the fix callers should migrate to
// =============================================================================

Future<int> _getValueAsync() async => 42;

// =============================================================================
// GOOD near-miss: sync-only return type, no FutureOr in sight
// =============================================================================

int _getValueSync() => 42;

// =============================================================================
// BAD/GOOD: overriding method is exempt — the FutureOr signature is
// inherited from the interface below and cannot be changed independently.
// The base declaration is still flagged; the override is not.
// =============================================================================

abstract class _Base {
  // expect_lint: avoid_futureor_return_type
  FutureOr<int> compute();

  // expect_lint: avoid_futureor_return_type
  FutureOr<int> get cachedTotal;
}

class _Impl extends _Base {
  @override
  FutureOr<int> compute() => 1;

  @override
  FutureOr<int> get cachedTotal => 1;
}

// =============================================================================
// BAD/GOOD: overriding WITHOUT the @override annotation is still exempt —
// Dart does not require @override to correctly implement an interface
// method, so the exemption must be resolution-based, not annotation-based.
// =============================================================================

class _UnannotatedImpl implements _Base {
  // No @override here on purpose — this still satisfies the interface and
  // must not be flagged as an independent declaration.
  FutureOr<int> compute() => 2;

  FutureOr<int> get cachedTotal => 2;
}

// =============================================================================
// BAD: nullable FutureOr<T>? is still a bare FutureOr return type
// =============================================================================

// expect_lint: avoid_futureor_return_type
FutureOr<int>? _getNullableValue() => null;

// =============================================================================
// BAD: mixin methods route through the same MethodDeclaration visitor
// =============================================================================

mixin _Mixin {
  // expect_lint: avoid_futureor_return_type
  FutureOr<int> mixinMethod() => 1;
}

// =============================================================================
// BAD: extension methods route through the same MethodDeclaration visitor
// =============================================================================

extension _Extension on String {
  // expect_lint: avoid_futureor_return_type
  FutureOr<int> extensionMethod() => 1;
}

// =============================================================================
// BAD: a typedef alias hides the `FutureOr` lexeme but resolves to exactly
// dart:async's FutureOr<T>, so the caller-side sync/async ambiguity is
// identical and must still be flagged. Detection is resolution-based
// (DartType.isDartAsyncFutureOr), not a source-text comparison.
// =============================================================================

typedef _MyFutureOr<T> = FutureOr<T>;

// expect_lint: avoid_futureor_return_type
_MyFutureOr<int> _getAliasedValue() => 42;

// =============================================================================
// GOOD near-miss: a user-defined class that merely SHARES the name FutureOr
// is not dart:async.FutureOr. It is an ordinary value wrapper with no
// sync/async ambiguity at all, so flagging it would be a false positive and
// the correction message ("make it async, return Future<T>") would be
// nonsense. This is the case the old lexeme-comparison check got wrong.
// =============================================================================

class _FakeFutureOr<T> {
  const _FakeFutureOr(this.value);
  final T value;
}

// This file already imports dart:async, so the real `FutureOr` name is taken
// and the wrapper cannot literally reuse it here; the unit test in
// test/rules/core/avoid_futureor_return_type_test.dart covers the exact
// `class FutureOr<T>` shadowing case in an import-free library.
_FakeFutureOr<int> _wrapValue(int v) => _FakeFutureOr<int>(v);
