// ignore_for_file: unused_local_variable, unused_element, unawaited_futures
// ignore_for_file: avoid_print, unused_field, avoid_types_on_closure_parameters
// Test fixture for async rules added in v2.3.10

import 'dart:async';

// =========================================================================
// avoid_future_then_in_async
// =========================================================================
// Warns when .then() is used inside an async function.

// BAD: Using .then() inside async function
Future<void> badFutureThenInAsync() async {
  // expect_lint: avoid_future_then_in_async
  fetchData().then((data) {
    processData(data);
  });
}

// BAD: Nested .then() in async function
Future<void> badNestedThenInAsync() async {
  // expect_lint: avoid_future_then_in_async
  fetchData().then((data) {
    return processData(data);
  }).then((result) {
    print(result);
  });
}

// GOOD: Using await instead of .then()
Future<void> goodUsingAwait() async {
  final data = await fetchData();
  processData(data);
}

// GOOD: Using .then() outside async function (sync function)
void goodThenInSyncFunction() {
  fetchData().then((data) {
    processData(data);
  });
}

// =========================================================================
// avoid_unawaited_future
// =========================================================================
// Warns when a Future is not awaited and not explicitly marked.

// BAD: Unawaited future in statement
void badUnawaitedFuture() {
  // expect_lint: avoid_unawaited_future
  saveData();
}

// BAD: Unawaited future in async function
Future<void> badUnawaitedFutureInAsync() async {
  // expect_lint: avoid_unawaited_future
  saveData();
}

// GOOD: Awaited future
Future<void> goodAwaitedFuture() async {
  await saveData();
}

// GOOD: Explicitly fire-and-forget with unawaited()
void goodUnawaitedExplicit() {
  unawaited(saveData());
}

// GOOD: Assigning future to variable (intentional)
void goodAssigningFuture() {
  final Future<void> future = saveData();
  // Will handle later
}

// =========================================================================
// avoid_unawaited_future - Safe fire-and-forget patterns (no lint expected)
// =========================================================================

// GOOD: cancel() in dispose() - sync method, widget is being destroyed
class MyWidget {
  StreamSubscription<int>? _subscription;

  void dispose() {
    _subscription?.cancel();
  }
}

// GOOD: .catchError() chain - errors are explicitly handled
class AnimationExample {
  final _scrollController = _MockScrollController();

  void scrollToPosition() {
    _scrollController
        .animateTo(100)
        .catchError((Object error, StackTrace stack) {});
  }
}

// GOOD: .ignore() - explicitly marked as fire-and-forget
void goodFutureIgnore() {
  saveData().ignore();
}

// BAD: cancel() outside dispose() - still needs explicit handling
void badCancelOutsideDispose() {
  StreamSubscription<int>? subscription;
  // expect_lint: avoid_unawaited_future
  subscription?.cancel();
}

// =========================================================================
// Helper mocks
// =========================================================================

Future<String> fetchData() async => 'data';
void processData(String data) {}
Future<void> saveData() async {}
void unawaited(Future<void> future) {}

class _MockScrollController {
  Future<void> animateTo(double offset) async {}
}

extension FutureIgnoreExtension<T> on Future<T> {
  void ignore() {}
}
