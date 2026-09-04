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
}

class _Impl extends _Base {
  @override
  FutureOr<int> compute() => 1;
}
