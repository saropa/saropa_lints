// Turns the "Rule Instantiation" dashboard warning
// (scripts/modules/_rule_metrics.py `_compute_rule_instantiation_stats`)
// into a CI-blocking test. That script only prints a soft warning on the
// project-health dashboard — nothing stops a PR from merging a rule
// category whose test file never gained a `Rule Instantiation` group. This
// test enumerates the same categories the Python script does and fails
// loudly (with a ready-to-paste group name) when the marker is missing from
// an existing category test file.
//
// Mirrors (must stay in sync with) the Python logic:
//   - category discovery: lib/src/rules/**/*_rules.dart, stem minus
//     "_rules", excluding all_rules.dart.
//   - test file resolution: {category}_rules_test / {category}_test,
//     falling back to the same pair for a split-category alias.
//   - marker check: literal substring "Rule Instantiation" anywhere in the
//     resolved test file's content.
// A category with NO resolved test file at all is a separate, pre-existing
// "unit test coverage" gap tracked by the dashboard's other metric — not
// this test's concern, so it is skipped rather than failed here.
library;

import 'dart:io';

import 'package:test/test.dart';

const String _marker = 'Rule Instantiation';

void main() {
  group('Rule Instantiation coverage', () {
    test('every rule category with a test file carries the marker', () {
      final rulesDir = Directory('lib/src/rules');
      final testDir = Directory('test');
      expect(rulesDir.existsSync(), isTrue, reason: 'lib/src/rules missing');
      expect(testDir.existsSync(), isTrue, reason: 'test/ missing');

      final categories = _collectCategories(rulesDir);
      final testIndex = _indexTestFiles(testDir);

      final missing = <String>[];
      for (final category in categories) {
        final testPath = _resolveTestPath(testIndex, category);
        if (testPath == null) continue; // Tracked separately; not this gate.
        final content = testPath.readAsStringSync();
        if (!content.contains(_marker)) {
          missing.add('$category (${testPath.path})');
        }
      }

      expect(
        missing,
        isEmpty,
        reason:
            'Categories missing a "$_marker" group in their test file:\n'
            '${missing.map((c) => '  - $c').join('\n')}\n\n'
            "Add: group('<category> - $_marker', () { test('<RuleClass>', "
            '() { assertRuleMetadata(<RuleClass>(), \'<rule_name>\'); }); '
            '}); — see test/support/rule_instantiation_assertions.dart.',
      );
    });
  });
}

/// Rule category names derived from `lib/src/rules/**/*_rules.dart`
/// filenames (stem minus the `_rules` suffix), excluding the barrel export.
List<String> _collectCategories(Directory rulesDir) {
  final categories = <String>[];
  for (final entity in rulesDir.listSync(recursive: true)) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    if (!name.endsWith('_rules.dart')) continue;
    if (name == 'all_rules.dart') continue;
    categories.add(name.substring(0, name.length - '_rules.dart'.length));
  }
  categories.sort();
  return categories;
}

/// `{stem: path}` for every `*_test.dart` under [testDir], excluding the
/// synthetic-project fixtures under `test/fixtures/`.
Map<String, File> _indexTestFiles(Directory testDir) {
  final index = <String, File>{};
  for (final entity in testDir.listSync(recursive: true)) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    if (!name.endsWith('_test.dart')) continue;
    final relative = entity.path.replaceAll('\\', '/');
    if (relative.contains('/fixtures/')) continue;
    final stem = name.substring(0, name.length - '.dart'.length);
    index[stem] = entity;
  }
  return index;
}

/// Maps a split rule-category name to the broader category whose test file
/// actually carries its coverage. Ported from
/// `scripts/modules/_rule_metrics.py` `_test_category_alias` — keep both in
/// sync if either changes.
String _testCategoryAlias(String category) {
  if (category.startsWith('code_quality_')) return 'code_quality';
  if (category.startsWith('security_')) return 'security';
  if (category.startsWith('widget_layout_')) return 'widget_layout';
  if (category.startsWith('widget_patterns_')) return 'widget_patterns';
  if (category.startsWith('ios_')) return 'ios';
  if (category == 'repo_integrity') return 'config';
  if (category == 'pubspec_constraint') return 'pubspec_constraint_parser';
  return category;
}

/// Resolves [category] to the test file backing it, honoring the alias
/// fallback — same stem order as the Python `_resolve_test_path`.
File? _resolveTestPath(Map<String, File> testIndex, String category) {
  final alias = _testCategoryAlias(category);
  final stems = <String>['${category}_rules_test', '${category}_test'];
  if (alias != category) {
    stems.addAll(['${alias}_rules_test', '${alias}_test']);
  }
  for (final stem in stems) {
    final file = testIndex[stem];
    if (file != null) return file;
  }
  return null;
}
