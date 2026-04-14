// ignore_for_file: unused_element
// Fixture for prefer_foreach_over_map_entries: prefer for-in over map.forEach.

// LINT: Map.forEach
void bad(Map<String, int> map) {
  map.forEach((k, v) => print('$k: $v'));
}

// OK: for-in over entries
void good(Map<String, int> map) {
  for (final e in map.entries) print('${e.key}: ${e.value}');
}
