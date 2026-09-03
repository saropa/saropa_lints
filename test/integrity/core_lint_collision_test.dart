// Validates that no saropa_lints rule name collides with a core
// Dart/Flutter analyzer lint name. The canonical list lives in
// scripts/modules/_tier_integrity.py (CORE_DART_LINT_NAMES); this
// test reads it at runtime so both sources stay in sync.

import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

/// Parse CORE_DART_LINT_NAMES from the Python tier integrity module.
/// Returns the set of known core Dart/Flutter lint names.
Set<String> _parseCoreNamesFromPython() {
  final file = File('scripts/modules/_tier_integrity.py');
  if (!file.existsSync()) {
    fail('Cannot find _tier_integrity.py — run from project root.');
  }

  final content = file.readAsStringSync();

  // Match quoted strings inside the CORE_DART_LINT_NAMES frozenset block.
  final blockMatch = RegExp(
    r'CORE_DART_LINT_NAMES.*?frozenset\(\{(.*?)\}\)',
    dotAll: true,
  ).firstMatch(content);

  if (blockMatch == null) {
    fail('Could not find CORE_DART_LINT_NAMES block in _tier_integrity.py');
  }

  // Extract all double-quoted identifiers from the block body.
  final names = RegExp(r'"(\w+)"')
      .allMatches(blockMatch.group(1)!)
      .map((m) => m.group(1)!)
      .toSet();

  // Sanity check: the set should have a reasonable number of entries.
  expect(
    names.length,
    greaterThan(100),
    reason: 'CORE_DART_LINT_NAMES seems too small (${names.length} entries)',
  );

  return names;
}

void main() {
  test('no saropa rule name collides with a core Dart lint name', () {
    // Read the Python-maintained reference set of core lint names.
    final coreNames = _parseCoreNamesFromPython();

    // Get all registered saropa_lints rule names.
    final saropaNames = allSaropaRules
        .map((rule) => rule.code.lowerCaseName)
        .toSet();

    // Intersect: any match is a collision that would produce duplicate
    // diagnostics and confuse ignore-comment prefixing.
    final collisions = saropaNames.intersection(coreNames);

    expect(
      collisions,
      isEmpty,
      reason:
          'saropa_lints rule names collide with core Dart lints:\n'
          '${collisions.toList()..sort()}\n\n'
          'Rename with a semantic suffix (_extended, _strict, _with_fix) '
          'or drop the rule if identical to the core lint.',
    );
  });
}
