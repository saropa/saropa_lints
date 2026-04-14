// ignore_for_file: unused_local_variable, unused_element, unused_catch_clause
// ignore_for_file: avoid_catches_without_on_clauses, empty_catches
// Test fixture for error handling catch rules

// =========================================================================
// avoid_catch_all
// =========================================================================
// Warns when using bare catch without an on clause.
// Use on Object catch for comprehensive handling, or specific types.

// BAD: Bare catch without type - implicit catch-all, may be accidental
Future<void> badCatchWithoutType() async {
  try {
    await fetchData();
    // expect_lint: avoid_catch_all
  } catch (e) {
    // Implicit catch-all - use explicit type to show intent
  }
}

// BAD: Bare catch even with rethrow - still implicit
Future<void> badCatchWithRethrow() async {
  try {
    await fetchData();
  } on FormatException catch (e) {
    // Handle parsing errors
    // expect_lint: avoid_catch_all
  } catch (e) {
    rethrow; // Bare catch - use "on Object catch" to be explicit
  }
}

// GOOD: on Object catch - deliberate comprehensive handling
Future<void> goodCatchObject() async {
  try {
    await fetchData();
  } on Object catch (e, stack) {
    // Catches EVERYTHING including Error types
    // This is the correct pattern for comprehensive error logging
    print('$e\n$stack');
  }
}

// GOOD: Catching specific exception types
Future<void> goodCatchSpecific() async {
  try {
    await fetchData();
  } on FormatException catch (e) {
    // Handle parsing errors
  } on HttpException catch (e) {
    // Handle network errors
  }
}

// =========================================================================
// avoid_catch_exception_alone
// =========================================================================
// Warns when on Exception catch is used without on Object catch fallback.
// on Exception misses Error types (StateError, TypeError, RangeError, etc.)

// BAD: on Exception catch alone - misses Error types!
Future<void> badCatchExceptionAlone() async {
  try {
    await fetchData();
    // expect_lint: avoid_catch_exception_alone
  } on Exception catch (e) {
    // DANGER: StateError, TypeError, RangeError will crash without logging!
  }
}

// GOOD: on Exception is OK if there's on Object fallback
Future<void> goodExceptionWithObjectFallback() async {
  try {
    await fetchData();
  } on Exception catch (e) {
    // Handle recoverable exceptions one way
    print('Exception: $e');
  } on Object catch (e, stack) {
    // Catch Error types (programming bugs) another way
    print('Error: $e\n$stack');
  }
}

// GOOD: Specific handlers with on Object fallback
Future<void> goodCatchWithObjectFallback() async {
  try {
    await fetchData();
  } on FormatException catch (e) {
    // Handle parsing errors
  } on Object catch (e, stack) {
    // Catch everything else including Error types
    print('$e\n$stack');
  }
}

// =========================================================================
// require_finally_cleanup
// =========================================================================
// Warns when cleanup code is in catch block instead of finally.

// BAD: Cleanup in catch block only
Future<void> badCleanupInCatch() async {
  late final Object file;
  // expect_lint: require_finally_cleanup
  try {
    file = await openFile('test.txt');
    await processFile(file);
  } catch (e) {
    await closeFile(file); // May not run!
  }
}

// BAD: Dispose in catch block
Future<void> badDisposeInCatch() async {
  late final Object controller;
  // expect_lint: require_finally_cleanup
  try {
    controller = createController();
    await useController(controller);
  } catch (e) {
    disposeController(controller); // May not run!
  }
}

// GOOD: Cleanup in finally block
Future<void> goodCleanupInFinally() async {
  late final Object file;
  try {
    file = await openFile('test.txt');
    await processFile(file);
  } catch (e) {
    print('Error: $e');
  } finally {
    await closeFile(file); // Always runs
  }
}

// GOOD: Dispose in finally block
Future<void> goodDisposeInFinally() async {
  late final Object controller;
  try {
    controller = createController();
    await useController(controller);
  } finally {
    disposeController(controller); // Always runs
  }
}

// =========================================================================
// Helper mocks
// =========================================================================

Future<String> fetchData() async => 'data';

class FormatException implements Exception {}

class HttpException implements Exception {}

Future<Object> openFile(String path) async => Object();
Future<void> processFile(Object file) async {}
Future<void> closeFile(Object file) async {}
Object createController() => Object();
Future<void> useController(Object controller) async {}
void disposeController(Object controller) {}
