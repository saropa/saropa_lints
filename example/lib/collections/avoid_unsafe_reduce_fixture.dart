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

// --- False-positive regression (6.0.4): reduce guarded by length check ---
// GOOD: reduce after early return when length < 2 must NOT trigger
int reduceWithLengthGuard(List<int> data) {
  if (data.length < 2) return data.isEmpty ? 0 : data.first;
  return data.reduce((a, b) => a + b);
}

// GOOD: reduce inside isNotEmpty block must NOT trigger
int reduceWithIsNotEmptyGuard(List<int> data) {
  if (data.isNotEmpty) {
    return data.reduce((a, b) => a + b);
  }
  return 0;
}
