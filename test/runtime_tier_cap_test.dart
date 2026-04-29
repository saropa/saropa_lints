import 'dart:io';

import 'package:saropa_lints/src/config/runtime_tier_cap.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart' show RuleTier;
import 'package:saropa_lints/src/tiers.dart' as tiers;
import 'package:test/test.dart';

// runtime_tier_cap: parse tier from analysis options YAML; rule cap by tier in tests.

void main() {
  group('parseSaropaTierFromCustomYaml', () {
    test('parses unquoted tier', () {
      expect(
        parseSaropaTierFromCustomYaml('saropa_tier: recommended\n'),
        'recommended',
      );
    });

    test('parses quoted tier', () {
      expect(
        parseSaropaTierFromCustomYaml("saropa_tier: 'essential'\n"),
        'essential',
      );
    });
  });

  group('parseSaropaTierFromPluginBlock', () {
    test('reads runtime_tier under saropa_lints', () {
      const yaml = '''
plugins:
  saropa_lints:
    runtime_tier: comprehensive
''';
      expect(parseSaropaTierFromPluginBlock(yaml), 'comprehensive');
    });

    test('reads saropa_tier alias', () {
      const yaml = '''
plugins:
  saropa_lints:
    saropa_tier: essential
''';
      expect(parseSaropaTierFromPluginBlock(yaml), 'essential');
    });
  });

  group('RuntimeTierCap', () {
    test('SAROPA_TIER caps pedantic-only rules off', () {
      final tmp = Directory.systemTemp.createTempSync('saropa_tier_cap_');
      addTearDown(() {
        try {
          tmp.deleteSync(recursive: true);
        } on Object {
          // Best-effort cleanup.
        }
      });

      File('${tmp.path}/analysis_options.yaml').writeAsStringSync('''
plugins:
  saropa_lints:
    diagnostics:
      avoid_debug_print: true
''');

      final pedanticOnly = tiers.pedanticOnlyRules.first;
      final essentialRule = tiers.essentialRules.first;
      expect(tiers.essentialRules.contains(pedanticOnly), isFalse);

      reloadRuntimeTierCapFromProject(tmp.path, {'SAROPA_TIER': 'essential'});
      expect(RuntimeTierCap.activeCap, RuleTier.essential);
      expect(RuntimeTierCap.ruleAllowedByCap(pedanticOnly), isFalse);
      expect(RuntimeTierCap.ruleAllowedByCap(essentialRule), isTrue);
      expect(RuntimeTierCap.ruleAllowedByCap('avoid_debug_print'), isFalse);
    });
  });
}
