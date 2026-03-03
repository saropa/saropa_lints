// ignore_for_file: unused_local_variable, unused_element

import 'dart:async';

/// Fixture for `avoid_unawaited_future` lint rule.

Future<void> _saveData() async {}

// BAD: Should trigger avoid_unawaited_future
void _bad() {
  // expect_lint: avoid_unawaited_future
  _saveData(); // Future not awaited — errors silently lost
}

// GOOD: Should NOT trigger avoid_unawaited_future
Future<void> _good() async {
  await _saveData(); // properly awaited
}

// Safe fire-and-forget: unawaited() explicitly marks intentional non-awaited Future
// (no expect_lint — must NOT trigger)
void _safeFireAndForget() {
  unawaited(_saveData());
}

// Safe: unawaited() with chained Future (e.g. .then()) — must NOT trigger
void _safeFireAndForgetChain() {
  unawaited(_saveData().then((_) {}));
}

void main() {}
