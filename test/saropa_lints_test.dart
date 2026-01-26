import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

/// All tier sets in tiers.dart, for validation.
const List<({String name, Set<String> rules})> _allTierSets =
    <({String name, Set<String> rules})>[
  (name: 'stylisticRules', rules: stylisticRules),
  (name: 'essentialRules', rules: essentialRules),
  (name: 'recommendedOnlyRules', rules: recommendedOnlyRules),
  (name: 'professionalOnlyRules', rules: professionalOnlyRules),
  (name: 'comprehensiveOnlyRules', rules: comprehensiveOnlyRules),
  (name: 'insanityOnlyRules', rules: insanityOnlyRules),
];

void main() {
  group('SaropaLints Plugin', () {
    test('createPlugin returns a PluginBase instance', () {
      final PluginBase plugin = createPlugin();
      expect(plugin, isA<PluginBase>());
    });

    test('createPlugin is callable multiple times', () {
      final PluginBase plugin1 = createPlugin();
      final PluginBase plugin2 = createPlugin();
      expect(plugin1, isA<PluginBase>());
      expect(plugin2, isA<PluginBase>());
    });
  });

  group('Tier Coverage Validation', () {
    // Compute once and share across tests
    late Set<String> pluginRuleNames;
    late Set<String> tierRuleNames;

    setUpAll(() {
      pluginRuleNames =
          allSaropaRules.map((LintRule rule) => rule.code.name).toSet();
      tierRuleNames = getAllDefinedRules();
    });

    test('all plugin rules must be in tiers.dart', () {
      final Set<String> missingFromTiers =
          pluginRuleNames.difference(tierRuleNames);

      expect(
        missingFromTiers,
        isEmpty,
        reason: 'Rules exist in plugin but not in tiers.dart:\n'
            '${missingFromTiers.toList()..sort()}\n\n'
            'Add these rules to the appropriate tier in lib/src/tiers.dart',
      );
    });

    test('all tier rules must exist in plugin', () {
      final Set<String> phantomRules =
          tierRuleNames.difference(pluginRuleNames);

      expect(
        phantomRules,
        isEmpty,
        reason: 'Rules in tiers.dart do not exist in plugin:\n'
            '${phantomRules.toList()..sort()}\n\n'
            'Remove these phantom rules from lib/src/tiers.dart',
      );
    });
  });

  group('Tier Integrity Validation', () {
    test('no rule appears in multiple tier sets', () {
      final Map<String, List<String>> ruleToSets = <String, List<String>>{};

      for (final tier in _allTierSets) {
        for (final String ruleName in tier.rules) {
          ruleToSets.putIfAbsent(ruleName, () => <String>[]).add(tier.name);
        }
      }

      final Map<String, List<String>> duplicates =
          Map<String, List<String>>.fromEntries(
        ruleToSets.entries
            .where((MapEntry<String, List<String>> e) => e.value.length > 1),
      );

      expect(
        duplicates,
        isEmpty,
        reason: 'Rules found in multiple tier sets:\n'
            '${duplicates.entries.map((e) => '  ${e.key}: ${e.value.join(', ')}').join('\n')}\n\n'
            'Each rule must appear in exactly one tier set.',
      );
    });

    test('every plugin rule is in exactly one tier set', () {
      final Set<String> pluginRuleNames =
          allSaropaRules.map((LintRule rule) => rule.code.name).toSet();

      final Set<String> allTierRuleNames = <String>{};
      for (final tier in _allTierSets) {
        allTierRuleNames.addAll(tier.rules);
      }

      final Set<String> missingRules =
          pluginRuleNames.difference(allTierRuleNames);

      expect(
        missingRules,
        isEmpty,
        reason: 'Rules not in any tier set:\n'
            '${missingRules.toList()..sort()}\n\n'
            'Every rule must be in exactly one tier set in tiers.dart.',
      );
    });

    test('no duplicate entries within any tier set', () {
      // Sets naturally deduplicate, so check the const lists
      // by verifying the count of each set matches expectations.
      // Since these are const Set<String>, Dart enforces uniqueness
      // at compile time. This test documents the invariant.
      final Set<String> allRules = <String>{};
      int totalCount = 0;

      for (final tier in _allTierSets) {
        totalCount += tier.rules.length;
        allRules.addAll(tier.rules);
      }

      expect(
        totalCount,
        allRules.length,
        reason: 'Total entries across all tier sets ($totalCount) '
            'exceeds unique rule count (${allRules.length}). '
            'A rule appears in multiple sets.',
      );
    });

    test('opinionated prefer_* rules must be in stylisticRules', () {
      final List<String> misclassified = <String>[];

      for (final LintRule rule in allSaropaRules) {
        if (rule is! SaropaLintRule) continue;
        if (rule.impact != LintImpact.opinionated) continue;

        final String name = rule.code.name;
        // All prefer_* opinionated rules are stylistic, no exceptions.
        // Non-prefer opinionated rules (avoid_*, require_*) are case-by-case.
        if (!name.startsWith('prefer_')) continue;
        if (!stylisticRules.contains(name)) {
          misclassified.add(name);
        }
      }

      misclassified.sort();

      expect(
        misclassified,
        isEmpty,
        reason: 'Opinionated prefer_* rules must be in '
            'stylisticRules, not a tier set:\n'
            '${misclassified.map((n) => '  $n').join('\n')}\n\n'
            'Move these rules to stylisticRules in lib/src/tiers.dart.',
      );
    });
  });
}
