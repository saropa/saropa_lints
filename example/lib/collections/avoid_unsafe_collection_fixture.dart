// ignore_for_file: unused_local_variable
// Test fixture for avoid_unsafe_collection_methods rule

void testUnsafeCollectionMethods() {
  final emptyList = <int>[];

  // BAD: Unsafe collection methods on potentially empty collections
  // expect_lint: avoid_unsafe_collection_methods
  final first = emptyList.first;

  // expect_lint: avoid_unsafe_collection_methods
  final last = emptyList.last;

  // expect_lint: avoid_unsafe_collection_methods
  final single = emptyList.single;

  // GOOD: Safe alternatives (should NOT trigger)
  final firstOrNull = emptyList.firstOrNull;
  final lastOrNull = emptyList.lastOrNull;
  final singleOrNull = emptyList.singleOrNull;

  // GOOD: Guarded by isNotEmpty check in if statement (should NOT trigger)
  if (emptyList.isNotEmpty) {
    final guardedFirst = emptyList.first;
    final guardedLast = emptyList.last;
  }

  // GOOD: Guarded by !isEmpty check (should NOT trigger)
  if (!emptyList.isEmpty) {
    final guardedFirst = emptyList.first;
  }

  // GOOD: Guarded by length check in ternary (should NOT trigger)
  final ternaryFirst = emptyList.isNotEmpty ? emptyList.first : 0;
  final ternaryLast = emptyList.length > 0 ? emptyList.last : 0;
  final ternaryWithLength = emptyList.length >= 1 ? emptyList.first : 0;
  final ternaryMultiple = emptyList.length > 1 ? emptyList.last : 0;
  final ternaryExactLength = emptyList.length == 1 ? emptyList.first : 0;
  final ternaryExactLengthTwo = emptyList.length == 2 ? emptyList.last : 0;

  // GOOD: Guarded by length comparison (should NOT trigger)
  if (emptyList.length > 0) {
    final guardedByLength = emptyList.first;
  }

  if (emptyList.length >= 1) {
    final guardedByLengthGe = emptyList.first;
  }

  if (emptyList.length != 0) {
    final guardedByLengthNe = emptyList.first;
  }

  // GOOD: Inverted guard - isEmpty check with access in else (should NOT trigger)
  if (emptyList.isEmpty) {
    // do nothing
  } else {
    final guardedInElse = emptyList.first;
  }
}
