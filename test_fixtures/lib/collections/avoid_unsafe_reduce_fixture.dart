// ignore_for_file: unused_local_variable
// Test fixture for avoid_unsafe_reduce rule

void testUnsafeReduce() {
  final emptyList = <int>[];

  // BAD: reduce on potentially empty collection
  // expect_lint: avoid_unsafe_reduce
  final sum = emptyList.reduce((a, b) => a + b);

  // GOOD: Use fold with initial value (should NOT trigger)
  final safeSum = emptyList.fold(0, (a, b) => a + b);
}
