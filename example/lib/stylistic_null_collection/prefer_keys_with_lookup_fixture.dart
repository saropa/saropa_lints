// ignore_for_file: avoid_print

/// Fixture for `prefer_keys_with_lookup` (opinionated opposite of .entries).

void badExamples(Map<String, int> map) {
  // LINT: .entries iteration — opposite style prefers .keys + lookup
  for (final entry in map.entries) {
    print(entry.value);
  }
}

void goodExamples(Map<String, int> map) {
  for (final key in map.keys) {
    print(map[key]);
  }
}
