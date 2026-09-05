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

// --- False-positive regression: reduce on non-empty literal receiver ---
// A list/set literal with only plain elements has a fixed, compile-time-known
// element count, so reduce() can never see zero elements and throw.

// GOOD: inline list literal with plain elements — always 3 elements, never
// empty. Mirrors the Levenshtein-style `[a, b, c].reduce(...)` pattern from
// the bug report.
int reduceOnNonEmptyListLiteral(int prev, int curr, int cost) {
  return [prev + 1, curr + 1, prev + cost].reduce((a, b) => a < b ? a : b);
}

// GOOD: inline set literal with plain elements — same reasoning as above.
int reduceOnNonEmptySetLiteral() {
  return <int>{1, 2, 3}.reduce((a, b) => a + b);
}

// BAD: empty list literal — provably empty, must still trigger.
// expect_lint: avoid_unsafe_reduce
int reduceOnEmptyListLiteral() {
  return <int>[].reduce((a, b) => a + b);
}

// BAD: spread element can contribute zero elements at runtime even though
// the literal has one syntactic entry — must still trigger.
// expect_lint: avoid_unsafe_reduce
int reduceOnSpreadListLiteral(List<int> maybeEmpty) {
  return [...maybeEmpty].reduce((a, b) => a + b);
}

// BAD: conditional element can resolve to zero elements — must still
// trigger.
// expect_lint: avoid_unsafe_reduce
int reduceOnIfElementListLiteral(bool cond, int x) {
  return [if (cond) x].reduce((a, b) => a + b);
}

// BAD: for-element can iterate zero times, producing zero elements — must
// still trigger.
// expect_lint: avoid_unsafe_reduce
int reduceOnForElementListLiteral(List<int> source) {
  return [for (final int i in source) i].reduce((a, b) => a + b);
}
