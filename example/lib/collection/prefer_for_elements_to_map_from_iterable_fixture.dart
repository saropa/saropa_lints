// ignore_for_file: unused_local_variable
// Fixture for prefer_for_elements_to_map_from_iterable.

void bad() {
  final items = ['a', 'b', 'c'];
  // expect_lint: prefer_for_elements_to_map_from_iterable
  final map = Map.fromIterable(items, key: (e) => e, value: (e) => e.length);
}

void good() {
  final items = ['a', 'b', 'c'];
  final map = {for (final e in items) e: e.length};
}
