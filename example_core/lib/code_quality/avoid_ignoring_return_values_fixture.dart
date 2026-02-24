// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `avoid_ignoring_return_values` lint rule.

// BAD: Should trigger avoid_ignoring_return_values
// expect_lint: avoid_ignoring_return_values
void _bad(List<int> list) {
  list.map((e) => e * 2); // Return value ignored — map result discarded
}

// GOOD: Should NOT trigger avoid_ignoring_return_values
void _good(List<int> list) {
  final doubled = list.map((e) => e * 2).toList(); // Return value used
}

// GOOD: Map mutation methods — return value is a convenience, side effect is the goal
void _goodMapMutation(Map<String, int> counts, Map<String, List<int>> grouped) {
  counts.update('key', (v) => v + 1, ifAbsent: () => 1);
  counts.putIfAbsent('other', () => 0);
  grouped.update('key', (v) => [...v, 1], ifAbsent: () => <int>[1]);
}
