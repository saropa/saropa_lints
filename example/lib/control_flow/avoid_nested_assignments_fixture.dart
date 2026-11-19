// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `avoid_nested_assignments` lint rule.

dynamic x;

// BAD: Should trigger avoid_nested_assignments
// expect_lint: avoid_nested_assignments
void _bad(dynamic Function() getValue) {
  if ((x = getValue()) != null) {} // Assignment nested inside condition
}

// GOOD: Should NOT trigger avoid_nested_assignments
void _good(dynamic Function() getValue) {
  x = getValue(); // Assignment as standalone statement
  if (x != null) {}
}

// GOOD: `(map[key] ??= value).method()` is the single-lookup grouping idiom.
void _goodGrouping(List<int> items, String Function(int) key) {
  final Map<String, List<int>> grouped = <String, List<int>>{};
  for (final int item in items) {
    (grouped[key(item)] ??= <int>[]).add(item);
  }
  final Map<String, Set<int>> sets = <String, Set<int>>{};
  final int n = (sets['a'] ??= <int>{}).length;
}

// BAD: only the `map[key] ??= ...` target form is exempt.
void _badNearMiss(List<int> items) {
  final Map<String, List<int>> grouped = <String, List<int>>{};
  List<int>? cache;
  // expect_lint: avoid_nested_assignments
  (cache = <int>[]).add(1); // plain `=` is not the idiom
  // expect_lint: avoid_nested_assignments
  (cache ??= <int>[]).add(1); // `??=` on a variable, not a map index
  // expect_lint: avoid_nested_assignments
  (grouped['a'] = <int>[]).add(1); // `=` on index, not `??=`
}
