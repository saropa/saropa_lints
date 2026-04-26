// ignore_for_file: avoid_print, unused_local_variable
// Test fixture for: prefer_extracting_repeated_map_lookup
// Source: lib/src/rules/config/sdk_migration_batch2_rules.dart

// Canonical violation: 3 reads of the same literal key.
void badRepeatedLookup(Map<String, int> config) {
  print(config['timeout']);
  print(config['timeout']);
  // expect_lint: prefer_extracting_repeated_map_lookup
  print(config['timeout']);
}

void goodExtracted(Map<String, int> config) {
  final timeout = config['timeout'];
  print(timeout);
  print(timeout);
  print(timeout);
}

// Guard: writes are not "lookups" — `map[k] = v` cannot be hoisted into
// a local, so they must not be counted toward the 3+ threshold.
void goodAllWrites(Map<String, int> cache) {
  cache['a'] = 1;
  cache['a'] = 2;
  cache['a'] = 3;
}

// Guard: one read already extracted into a local, plus writes — the
// rule should NOT fire (the duplicate-read concern is already resolved
// and the writes are unfixable).
void goodReadThenWrites(Map<String, int> mostRecentByKey) {
  const String key = 'k';
  final int? existing = mostRecentByKey[key];
  if (existing == null) {
    mostRecentByKey[key] = 1;
  } else {
    mostRecentByKey[key] = 2;
  }
}

// Guard: same-spelled loop variables in three different scopes are
// three independent values, not three lookups of one. Element-based
// bucketing must keep them in separate buckets.
void goodSameNameDifferentScopes(
  List<String> orgs,
  List<String> families,
  List<String> groups,
) {
  final Map<String, String> cache = <String, String>{};

  for (final String uuid in orgs) {
    cache[uuid] = 'org';
  }

  for (final String uuid in families) {
    cache[uuid] = 'family';
  }

  for (final String uuid in groups) {
    cache[uuid] = 'group';
  }
}

// Guard: read inside one loop + writes in another loop using a
// same-spelled but distinctly-scoped variable. The third occurrence
// must not be flagged.
void goodReadInOneLoopWriteInAnother(
  List<String> activities,
  List<String> contactUUIDs,
) {
  final Map<String, int> counts = <String, int>{};

  for (final String uuid in activities) {
    counts[uuid] = (counts[uuid] ?? 0) + 1;
  }

  for (final String uuid in contactUUIDs) {
    final int count = counts[uuid] ?? 0;
    print(count);
  }
}

// Guard: different maps with the same key text are not the same
// lookup.
void goodDifferentMaps(
  Map<String, int> mapA,
  Map<String, int> mapB,
  Map<String, int> mapC,
) {
  print(mapA['k']);
  print(mapB['k']);
  print(mapC['k']);
}

// Positive: 3+ reads of the same literal key remain a violation even
// when interleaved with writes.
void badThreeReadsLiteralKey(Map<String, int> json) {
  print(json['country.id']);
  print(json['country.id']);
  // expect_lint: prefer_extracting_repeated_map_lookup
  print(json['country.id']);
}
