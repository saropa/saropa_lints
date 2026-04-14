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

  // GOOD: Collection-if guard (should NOT trigger)
  final collectionIfList = <int>[
    if (emptyList.isNotEmpty) emptyList.first,
    if (emptyList.length > 0) emptyList.last,
    if (!emptyList.isEmpty) emptyList.first,
  ];

  // GOOD: Collection-if with else inverted guard (should NOT trigger)
  final collectionIfElse = <int>[
    if (emptyList.isEmpty) 0 else emptyList.first,
  ];

  // GOOD: Nested property access with collection-if guard (should NOT trigger)
  final options = _TestOptions(colors: <int>[1, 2, 3]);
  final colorList = <int>[
    if (options.colors.isNotEmpty) options.colors.first,
    if (options.colors.length > 0) options.colors.last,
  ];

  // BAD: Collection-if without proper guard (SHOULD trigger)
  // expect_lint: avoid_unsafe_collection_methods
  final badCollectionIf = <int>[emptyList.first];
}

class _TestOptions {
  const _TestOptions({required this.colors});
  final List<int> colors;
}

// Test enum for .values access
enum TestEnum { one, two, three }

void testGuaranteedNonEmptyCollections() {
  // GOOD: String.split() always returns at least one element (should NOT trigger)
  final String text = 'hello|world';
  final splitFirst = text.split('|').first;
  final splitLast = text.split('|').last;
  final splitSingle = 'single'.split('x').first; // Returns ['single']

  // GOOD: Empty string split still returns one element (should NOT trigger)
  final emptyStringSplit = ''.split(',').first; // Returns ['']

  // GOOD: Enum.values is never empty (should NOT trigger)
  final enumFirst = TestEnum.values.first;
  final enumLast = TestEnum.values.last;

  // GOOD: Chained split access (should NOT trigger)
  final chainedSplit = 'a.b.c'.split('.').last;
  final nestedSplit = 'key=value'.split('=').first.split('_').last;

  // BAD: Non-split method results can be empty (SHOULD trigger)
  final filtered = <int>[1, 2, 3].where((int x) => x > 10);
  // expect_lint: avoid_unsafe_collection_methods
  final filteredFirst = filtered.first;

  // BAD: Regular list access without guard (SHOULD trigger)
  final regularList = <String>[];
  // expect_lint: avoid_unsafe_collection_methods
  final regularFirst = regularList.first;
}
