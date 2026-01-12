// ignore_for_file: unused_local_variable, unused_element, unused_catch_clause
// ignore_for_file: avoid_catches_without_on_clauses, empty_catches
// Test fixture for error handling rules added in v2.3.10

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
// Helper mocks
// =========================================================================

Future<String> fetchData() async => 'data';

class FormatException implements Exception {}

class HttpException implements Exception {}
