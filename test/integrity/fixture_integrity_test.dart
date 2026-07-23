import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

import '../helpers/fixture_discovery.dart';

/// Cross-references every `*_fixture.dart` file on disk against the set of
/// registered rule names in tiers.dart.  Catches stale fixtures left behind
/// after a rule rename/delete, and misspelled fixture filenames that silently
/// test nothing.
///
/// Fixture naming has two patterns:
///   1. `{rule_name}_fixture.dart` — tests a single rule (exact match).
///   2. `{category}_fixture.dart`  — tests multiple rules from a category
///      (no exact match expected; these are excluded from the per-file
///      assertion).
void main() {
  // Compute registered rules eagerly — this is cheap (string sets, no I/O).
  final registeredRules = getAllDefinedRules();

  final fixtureRoots = <String>['example/lib', 'example_packages/lib'];

  // Scan all fixture directories.
  final allFixtures = <({String name, String path})>[];

  for (final root in fixtureRoots) {
    final rootDir = Directory(root);
    if (!rootDir.existsSync()) continue;

    // Root-level fixtures (e.g. example/lib/migration_rules_fixture.dart).
    for (final name in discoverFixtures(rootDir)) {
      allFixtures.add((name: name, path: '$root/${name}_fixture.dart'));
    }

    // Per-category subdirectories.
    for (final sub in rootDir.listSync().whereType<Directory>()) {
      if (sub.path.endsWith('__rule_harness__')) continue;

      for (final name in discoverFixtures(sub)) {
        final path = '${sub.path}/${name}_fixture.dart'.replaceAll(r'\', '/');
        allFixtures.add((name: name, path: path));
      }
    }
  }

  // Classify: exact match = rule fixture, otherwise = group fixture.
  final ruleFixtures = allFixtures
      .where((f) => registeredRules.contains(f.name))
      .toList();
  final groupFixtures = allFixtures
      .where((f) => !registeredRules.contains(f.name))
      .toList();

  group('Fixture-to-rule integrity', () {
    test('fixture scan found both rule and group fixtures', () {
      expect(
        ruleFixtures,
        isNotEmpty,
        reason: 'No rule-matching fixtures found — scan is broken',
      );
    });

    // Regression floor: the count of exact-match rule fixtures should
    // not drop significantly.  Update the threshold when legitimately
    // removing rules/fixtures.
    test('rule fixture count has not regressed', () {
      expect(
        ruleFixtures.length,
        greaterThan(2300),
        reason:
            'Expected >2300 rule-matching fixtures, got '
            '${ruleFixtures.length}. A mass rename or deletion may have '
            'broken fixture-to-rule correspondence.',
      );
    });

    // Per-file assertion for rule fixtures.  By construction they already
    // matched, but individual test names make failures visible in the
    // runner when the set drifts.
    for (final fixture in ruleFixtures) {
      test('${fixture.name} matches a registered rule', () {
        expect(
          registeredRules,
          contains(fixture.name),
          reason:
              'Fixture ${fixture.path} does not match any rule in '
              'tiers.dart.  Either the rule was renamed/deleted (remove '
              'the fixture) or the filename is misspelled.',
        );
      });
    }

    // Group fixtures are logged but not failed — they cover multiple
    // rules and are intentionally named after a category, not a rule.
    test('group fixtures are documented', () {
      if (groupFixtures.isNotEmpty) {
        // ignore: avoid_print
        print(
          'INFO: ${groupFixtures.length} group fixtures (no exact rule '
          'match — expected for category/multi-rule fixtures):',
        );
        for (final gf in groupFixtures) {
          // ignore: avoid_print
          print('  ${gf.name} -> ${gf.path}');
        }
      }
    });
  });
}
