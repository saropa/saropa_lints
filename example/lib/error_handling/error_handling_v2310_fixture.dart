// ignore_for_file: unused_local_variable, unused_element, unused_catch_clause
// ignore_for_file: avoid_catches_without_on_clauses, empty_catches
// Test fixture for error handling rules added in v2.3.10

// =========================================================================
// avoid_catch_all
// =========================================================================
// Warns when catching generic Exception or Object without specific type.

// BAD: Catch without type
Future<void> badCatchWithoutType() async {
  try {
    await fetchData();
    // expect_lint: avoid_catch_all
  } catch (e) {
    // Catches everything including bugs!
  }
}

// BAD: Catching Exception (too broad)
Future<void> badCatchException() async {
  try {
    await fetchData();
    // expect_lint: avoid_catch_all
  } on Exception catch (e) {
    // Still too broad
  }
}

// BAD: Catching Object (catches everything)
Future<void> badCatchObject() async {
  try {
    await fetchData();
    // expect_lint: avoid_catch_all
  } on Object catch (e) {
    // Catches absolutely everything
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

// GOOD: Catching specific types with fallback that rethrows
Future<void> goodCatchWithRethrow() async {
  try {
    await fetchData();
  } on FormatException catch (e) {
    // Handle parsing errors
  } catch (e) {
    rethrow; // Re-throwing is acceptable
  }
}

// =========================================================================
// Helper mocks
// =========================================================================

Future<String> fetchData() async => 'data';

class FormatException implements Exception {}

class HttpException implements Exception {}
