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

// Guard: mirrors the contacts `swipe()` shape — one extracted read plus
// multiple assignment writes, including a write after index mutation.
// Writes must not count as repeated lookups.
void goodSwipeLikeReadThenWrites(List<int?> oldLine, bool positive) {
  final List<int?> newLine = List<int?>.filled(oldLine.length, null);

  int newIndex = positive ? oldLine.length - 1 : 0;
  for (
    int oldIndex = positive ? oldLine.length - 1 : 0;
    positive ? oldIndex >= 0 : oldIndex < oldLine.length;
    positive ? oldIndex-- : oldIndex++
  ) {
    final int? oldValue = oldLine[oldIndex];
    if (oldValue == null) continue;

    final int? currentNew = newLine[newIndex];
    if (currentNew == null) {
      newLine[newIndex] = oldValue;
    } else if (currentNew == oldValue) {
      newLine[newIndex] = currentNew * 2;
      newIndex = positive ? newIndex - 1 : newIndex + 1;
    } else {
      newIndex = positive ? newIndex - 1 : newIndex + 1;
      newLine[newIndex] = oldValue;
    }
  }
}

// Guard: shadowing a parameter with a block-local of the same name should
// never trigger this rule by itself (no `[]` lookup involved).
void goodInnerLocalShadowsParameter(List<String>? names) {
  if (names == null) return;
  final List<List<String>> groups = <List<String>>[names];
  if (groups.length == 1) {
    final List<String>? names = groups.firstOrNull;
    if (names?.length == 1 && names?.firstOrNull == 'system') {
      print('ok');
    }
  }
}

// Guard: same-spelled loop variables in sibling scopes must not conflate.
// Writes are skipped; the single read remains below threshold.
void goodSameNameLoopVarsInSiblingScopes(
  List<String> contacts,
  List<String> ids,
) {
  final Map<String, int> contactIndustryMap = <String, int>{};

  for (final String contact in contacts) {
    contactIndustryMap[contact] = 1;
  }

  for (final String id in ids) {
    final String? contact = contacts.firstWhereOrNull(
      (String c) => c == id,
    );
    if (contact == null) continue;

    final int? types = contactIndustryMap[contact];
    if (types != null) {
      print(types);
    }

    contactIndustryMap[contact] = 2;
  }
}
