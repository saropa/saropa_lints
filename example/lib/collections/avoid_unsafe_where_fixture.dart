// ignore_for_file: unused_local_variable
// Test fixture for avoid_unsafe_where_methods rule

class Item {
  final int id;
  final bool isActive;
  Item(this.id, {this.isActive = false});
}

void testUnsafeWhereMethods() {
  final items = <Item>[Item(1), Item(2, isActive: true)];
  final emptyList = <Item>[];

  // BAD: firstWhere without orElse - throws if no match
  // expect_lint: avoid_unsafe_where_methods
  final first = items.firstWhere((e) => e.id == 999);

  // BAD: lastWhere without orElse - throws if no match
  // expect_lint: avoid_unsafe_where_methods
  final last = items.lastWhere((e) => e.isActive);

  // BAD: singleWhere without orElse - throws if no match
  // expect_lint: avoid_unsafe_where_methods
  final single = items.singleWhere((e) => e.id == 1);

  // SAFE but verbose: firstWhere WITH orElse
  // expect_lint: prefer_where_or_null
  final withOrElse = items.firstWhere(
    (e) => e.id == 999,
    orElse: () => Item(0),
  );

  // GOOD: Using firstWhereOrNull from collection package (should NOT trigger)
  // final safe = items.firstWhereOrNull((e) => e.id == 999);
}

void testOnDifferentCollectionTypes() {
  final mySet = <int>{1, 2, 3};
  final myQueue = <String>[];

  // BAD: Works on Set too
  // expect_lint: avoid_unsafe_where_methods
  final fromSet = mySet.firstWhere((e) => e > 10);
}

void testSafeUsageWithOrElse() {
  final items = <int>[1, 2, 3];

  // INFO: This has orElse - safe but verbose, prefer *OrNull pattern
  // expect_lint: prefer_where_or_null
  final withOrElse = items.firstWhere((e) => e > 10, orElse: () => 0);

  // BEST: Using firstWhereOrNull with ?? (should NOT trigger either rule)
  // final best = items.firstWhereOrNull((e) => e > 10) ?? 0;
}
