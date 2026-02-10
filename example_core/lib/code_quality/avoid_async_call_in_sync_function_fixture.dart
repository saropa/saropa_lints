// ignore_for_file: unused_local_variable, unused_element, unused_field
// ignore_for_file: avoid_print, unawaited_futures, avoid_unawaited_future
// ignore_for_file: dead_code
// Test fixture for avoid_async_call_in_sync_function rule

import 'dart:async';

// =========================================================================
// avoid_async_call_in_sync_function
// =========================================================================

// ---- BAD: Async calls in sync functions without handling ----

// BAD: Fire-and-forget in a regular sync function
void badFireAndForget() {
  // expect_lint: avoid_async_call_in_sync_function
  fetchData();
}

// BAD: cancel() outside lifecycle methods
void badCancelOutsideDispose() {
  StreamSubscription<int>? subscription;
  // expect_lint: avoid_async_call_in_sync_function
  subscription?.cancel();
}

// BAD: Async call in a non-lifecycle sync method
void badSyncHelper() {
  // expect_lint: avoid_async_call_in_sync_function
  saveData();
}

// ---- GOOD: Handled async calls ----

// GOOD: Wrapped with unawaited()
void goodUnawaited() {
  unawaited(fetchData());
}

// GOOD: Wrapped with unawaited() and null-aware call
void goodUnawaitedNullAware() {
  StreamSubscription<int>? subscription;
  unawaited(subscription?.cancel() ?? Future<void>.value());
}

// GOOD: Assigned to variable
void goodAssigned() {
  final Future<String> future = fetchData();
}

// GOOD: Returned from function
Future<String> goodReturned() {
  return fetchData();
}

// GOOD: Passed as argument
void goodPassedAsArgument() {
  unawaited(fetchData());
}

// GOOD: Chained with .then()
void goodChainedThen() {
  fetchData().then((String data) => print(data));
}

// GOOD: Chained with .catchError()
void goodChainedCatchError() {
  fetchData().catchError((Object error) => 'fallback');
}

// GOOD: Chained with .whenComplete()
void goodChainedWhenComplete() {
  fetchData().whenComplete(() => print('done'));
}

// GOOD: Chained with .ignore()
void goodChainedIgnore() {
  fetchData().ignore();
}

// GOOD: In async function (not our concern)
Future<void> goodInAsyncFunction() async {
  await fetchData();
}

// ---- GOOD: Lifecycle cleanup patterns ----

// GOOD: cancel() in dispose()
class _GoodDisposeCancel extends _MockState<_MockWidget> {
  StreamSubscription<int>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

// GOOD: close() in dispose()
class _GoodDisposeClose extends _MockState<_MockWidget> {
  final StreamController<int> _controller = StreamController<int>();

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}

// GOOD: cancel() in didUpdateWidget()
class _GoodDidUpdateCancel extends _MockState<_MockWidget> {
  StreamSubscription<int>? _subscription;

  void didUpdateWidget(_MockWidget oldWidget) {
    _subscription?.cancel();
  }
}

// GOOD: cancel() in deactivate()
class _GoodDeactivateCancel extends _MockState<_MockWidget> {
  StreamSubscription<int>? _subscription;

  void deactivate() {
    _subscription?.cancel();
  }
}

// GOOD: StreamController.close() in onDone callback
void goodCloseInOnDone() {
  final StreamController<int> output = StreamController<int>();
  final StreamController<int> input = StreamController<int>();
  input.stream.listen(
    (int data) {},
    onDone: () {
      output.close();
    },
  );
}

// =========================================================================
// Helper mocks
// =========================================================================

Future<String> fetchData() async => 'data';
Future<void> saveData() async {}

class _MockWidget {
  const _MockWidget();
}

class _MockState<T> {
  void dispose() {}
}
