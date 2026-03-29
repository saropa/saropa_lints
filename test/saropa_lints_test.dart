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
      (name: 'pedanticOnlyRules', rules: pedanticOnlyRules),
    ];

void main() {
  group('SaropaLints Plugin', () {
    test('allSaropaRules returns non-empty list', () {
      final rules = allSaropaRules;
      expect(rules, isNotEmpty);
    });

    test('allSaropaRules returns SaropaLintRule instances', () {
      final rules = allSaropaRules;
      for (final rule in rules) {
        expect(rule, isA<SaropaLintRule>());
      }
    });
  });

  group('Tier Coverage Validation', () {
    // Compute once and share across tests
    late Set<String> pluginRuleNames;
    late Set<String> tierRuleNames;

    setUpAll(() {
      pluginRuleNames = allSaropaRules
          .map((SaropaLintRule rule) => rule.code.lowerCaseName)
          .toSet();
      tierRuleNames = getAllDefinedRules();
    });

    test('all plugin rules must be in tiers.dart', () {
      final Set<String> missingFromTiers = pluginRuleNames.difference(
        tierRuleNames,
      );

      expect(
        missingFromTiers,
        isEmpty,
        reason:
            'Rules exist in plugin but not in tiers.dart:\n'
            '${missingFromTiers.toList()..sort()}\n\n'
            'Add these rules to the appropriate tier in lib/src/tiers.dart',
      );
    });

    test('all tier rules must exist in plugin', () {
      final Set<String> phantomRules = tierRuleNames.difference(
        pluginRuleNames,
      );

      expect(
        phantomRules,
        isEmpty,
        reason:
            'Rules in tiers.dart do not exist in plugin:\n'
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
            ruleToSets.entries.where(
              (MapEntry<String, List<String>> e) => e.value.length > 1,
            ),
          );

      expect(
        duplicates,
        isEmpty,
        reason:
            'Rules found in multiple tier sets:\n'
            '${duplicates.entries.map((e) => '  ${e.key}: ${e.value.join(', ')}').join('\n')}\n\n'
            'Each rule must appear in exactly one tier set.',
      );
    });

    test('every plugin rule is in exactly one tier set', () {
      final Set<String> pluginRuleNames = allSaropaRules
          .map((SaropaLintRule rule) => rule.code.lowerCaseName)
          .toSet();

      final Set<String> allTierRuleNames = <String>{};
      for (final tier in _allTierSets) {
        allTierRuleNames.addAll(tier.rules);
      }

      final Set<String> missingRules = pluginRuleNames.difference(
        allTierRuleNames,
      );

      expect(
        missingRules,
        isEmpty,
        reason:
            'Rules not in any tier set:\n'
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
        reason:
            'Total entries across all tier sets ($totalCount) '
            'exceeds unique rule count (${allRules.length}). '
            'A rule appears in multiple sets.',
      );
    });

    test('opinionated prefer_* rules must be in stylisticRules', () {
      final List<String> misclassified = <String>[];

      for (final SaropaLintRule rule in allSaropaRules) {
        if (rule.impact != LintImpact.opinionated) continue;

        final String name = rule.code.lowerCaseName;
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
        reason:
            'Opinionated prefer_* rules must be in '
            'stylisticRules, not a tier set:\n'
            '${misclassified.map((n) => '  $n').join('\n')}\n\n'
            'Move these rules to stylisticRules in lib/src/tiers.dart.',
      );
    });
  });

  group('Package Rule Set Validation', () {
    late Set<String> pluginRuleNames;
    late Map<String, Set<String>> pkgSets;

    setUpAll(() {
      pluginRuleNames = allSaropaRules
          .map((SaropaLintRule rule) => rule.code.lowerCaseName)
          .toSet();
      pkgSets = packageRuleSets;
    });

    test('all package rules must exist in plugin', () {
      final Set<String> allPackageRules = <String>{};
      for (final rules in pkgSets.values) {
        allPackageRules.addAll(rules);
      }

      final Set<String> phantomRules = allPackageRules.difference(
        pluginRuleNames,
      );

      expect(
        phantomRules,
        isEmpty,
        reason:
            'Rules in package sets do not exist in plugin:\n'
            '${phantomRules.toList()..sort()}\n\n'
            'Remove these phantom rules from package sets in '
            'lib/src/tiers.dart',
      );
    });

    test('package rules must be in a tier set', () {
      final Set<String> tierRuleNames = getAllDefinedRules();
      final Set<String> allPackageRules = <String>{};
      for (final rules in pkgSets.values) {
        allPackageRules.addAll(rules);
      }

      final Set<String> orphaned = allPackageRules.difference(tierRuleNames);

      expect(
        orphaned,
        isEmpty,
        reason:
            'Package rules not in any tier set:\n'
            '${orphaned.toList()..sort()}\n\n'
            'Package sets are orthogonal to tiers. Every rule '
            'in a package set must also be in a tier set.',
      );
    });

    test('allPackages matches defaultPackages keys', () {
      final Set<String> allSet = allPackages.toSet();
      final Set<String> defaultKeys = defaultPackages.keys.toSet();

      expect(
        allSet,
        defaultKeys,
        reason:
            'allPackages and defaultPackages.keys must match.\n'
            'In allPackages only: ${allSet.difference(defaultKeys)}\n'
            'In defaultPackages only: ${defaultKeys.difference(allSet)}',
      );
    });

    test('allPackages matches packageRuleSets keys', () {
      final Set<String> allSet = allPackages.toSet();
      final Set<String> ruleSetKeys = pkgSets.keys.toSet();

      expect(
        allSet,
        ruleSetKeys,
        reason:
            'allPackages and packageRuleSets.keys must match.\n'
            'In allPackages only: ${allSet.difference(ruleSetKeys)}\n'
            'In packageRuleSets only: ${ruleSetKeys.difference(allSet)}',
      );
    });

    test('getRulesDisabledByPackages returns empty when all enabled', () {
      final result = getRulesDisabledByPackages(defaultPackages);
      expect(result, isEmpty);
    });

    test('getRulesDisabledByPackages disables rules for disabled package', () {
      final settings = Map<String, bool>.of(defaultPackages);
      settings['flame'] = false;

      final result = getRulesDisabledByPackages(settings);

      // Flame rules should be disabled (they're not in other sets)
      expect(result, contains('avoid_creating_vector_in_update'));
      expect(result, contains('avoid_redundant_async_on_load'));
    });

    test('shared rules stay enabled if any package still uses them', () {
      final settings = Map<String, bool>.of(defaultPackages);
      settings['firebase'] = false;

      final result = getRulesDisabledByPackages(settings);

      // Database shared rules should still be enabled via isar/hive/sqflite
      expect(result, isNot(contains('avoid_database_in_build')));
      expect(result, isNot(contains('require_database_migration')));

      // Firebase-only rules should be disabled
      expect(result, contains('require_firebase_init_before_use'));
    });
  });

  group('flutterStylisticRules Validation', () {
    test('flutterStylisticRules is a subset of stylisticRules', () {
      final notInStylistic = flutterStylisticRules.difference(stylisticRules);

      expect(
        notInStylistic,
        isEmpty,
        reason:
            'flutterStylisticRules contains rules not in stylisticRules:\n'
            '${notInStylistic.toList()..sort()}\n\n'
            'flutterStylisticRules must be a subset of stylisticRules.',
      );
    });

    test('all widget-only stylistic rules are in flutterStylisticRules', () {
      final widgetOnlyRules = <String>{};
      for (final rule in allSaropaRules) {
        final name = rule.code.lowerCaseName;
        if (!stylisticRules.contains(name)) continue;
        final fileTypes = rule.applicableFileTypes;
        if (fileTypes != null && fileTypes.length == 1) {
          // Rule only applies to widget files
          final typeName = fileTypes.first.toString();
          if (typeName.contains('widget')) {
            widgetOnlyRules.add(name);
          }
        }
      }

      final missing = widgetOnlyRules.difference(flutterStylisticRules);
      expect(
        missing,
        isEmpty,
        reason:
            'Widget-only stylistic rules missing from '
            'flutterStylisticRules:\n'
            '${missing.toList()..sort()}\n\n'
            'Add these to flutterStylisticRules in lib/src/tiers.dart.',
      );
    });
  });

  group('exampleBad / exampleGood Validation', () {
    test('exampleBad and exampleGood are always paired', () {
      final badOnly = <String>[];
      final goodOnly = <String>[];

      for (final rule in allSaropaRules) {
        final hasBad = rule.exampleBad != null;
        final hasGood = rule.exampleGood != null;
        if (hasBad && !hasGood) badOnly.add(rule.code.lowerCaseName);
        if (hasGood && !hasBad) goodOnly.add(rule.code.lowerCaseName);
      }

      expect(
        badOnly,
        isEmpty,
        reason:
            'Rules with exampleBad but no exampleGood:\n'
            '${badOnly.join('\n')}\n\n'
            'Always provide both examples.',
      );
      expect(
        goodOnly,
        isEmpty,
        reason:
            'Rules with exampleGood but no exampleBad:\n'
            '${goodOnly.join('\n')}\n\n'
            'Always provide both examples.',
      );
    });

    test('examples are non-empty strings', () {
      final empty = <String>[];

      for (final rule in allSaropaRules) {
        final name = rule.code.lowerCaseName;
        if (rule.exampleBad != null && rule.exampleBad!.trim().isEmpty) {
          empty.add('$name.exampleBad');
        }
        if (rule.exampleGood != null && rule.exampleGood!.trim().isEmpty) {
          empty.add('$name.exampleGood');
        }
      }

      expect(
        empty,
        isEmpty,
        reason: 'Examples must not be blank:\n${empty.join('\n')}',
      );
    });

    test('exampleBad differs from exampleGood', () {
      final identical = <String>[];

      for (final rule in allSaropaRules) {
        if (rule.exampleBad == null || rule.exampleGood == null) continue;
        if (rule.exampleBad == rule.exampleGood) {
          identical.add(rule.code.lowerCaseName);
        }
      }

      expect(
        identical,
        isEmpty,
        reason:
            'Rules where exampleBad == exampleGood (no diff shown):\n'
            '${identical.join('\n')}',
      );
    });

    test('conflicting pair examples are swapped', () {
      // For conflicting pairs, rule A's exampleBad should equal B's
      // exampleGood and vice versa. Verify a few known pairs.
      final ruleMap = <String, SaropaLintRule>{};
      for (final rule in allSaropaRules) {
        ruleMap[rule.code.lowerCaseName] = rule;
      }

      void checkPair(String ruleA, String ruleB) {
        final a = ruleMap[ruleA];
        final b = ruleMap[ruleB];
        if (a == null || b == null) return;
        if (a.exampleBad == null || b.exampleGood == null) return;

        expect(
          a.exampleBad,
          b.exampleGood,
          reason: "$ruleA.exampleBad should == $ruleB.exampleGood",
        );
        expect(
          a.exampleGood,
          b.exampleBad,
          reason: "$ruleA.exampleGood should == $ruleB.exampleBad",
        );
      }

      checkPair('prefer_single_quotes', 'prefer_double_quotes');
      checkPair('prefer_relative_imports', 'prefer_absolute_imports');
      checkPair('prefer_var_over_explicit_type', 'prefer_type_over_var');
      checkPair(
        'prefer_sizedbox_over_container',
        'prefer_container_over_sizedbox',
      );
      checkPair(
        'prefer_text_rich_over_richtext',
        'prefer_richtext_over_text_rich',
      );
      checkPair('prefer_edgeinsets_symmetric', 'prefer_edgeinsets_only');
      checkPair(
        'prefer_expanded_over_flexible',
        'prefer_flexible_over_expanded',
      );
      checkPair('prefer_material_theme_colors', 'prefer_explicit_colors');
      checkPair(
        'prefer_null_aware_assignment',
        'prefer_explicit_null_assignment',
      );
      checkPair('prefer_if_null_over_ternary', 'prefer_ternary_over_if_null');
    });
  });
}
