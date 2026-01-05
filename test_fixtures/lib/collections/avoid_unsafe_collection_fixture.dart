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
}
