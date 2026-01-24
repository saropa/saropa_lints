import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

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
}
