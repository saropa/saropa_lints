// ignore_for_file: avoid_print

/// Fixture for `prefer_map_entries_iteration`.

void badExamples(Map<String, int> map) {
  // LINT: .keys + map[key] duplicates lookups
  for (final key in map.keys) {
    final value = map[key];
    print('$key: $value');
  }
}

void goodExamples(Map<String, int> map) {
  for (final entry in map.entries) {
    print('${entry.key}: ${entry.value}');
  }
}
