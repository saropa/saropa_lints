/// Module overview (comment coverage pass).
/// comment-coverage: module overview (batch).
///
/// Analyzer-backed tests for `runtime_tier_cap_test` (runtime tier cap).
///
/// Uses `// LINT` markers and `example/` fixtures per CONTRIBUTING.md.
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

  // The in-process analyzer plugin must NOT run the full enabled rule set, or the
  // analysis server retains the whole project's resolved model and grows to a
  // multi-GB OOM hang. These tests pin the fix: the plugin path defaults to the
  // essential cap when nothing is configured, an explicit tier still overrides
  // that default, and the out-of-process scan path stays uncapped.
  group('in-process plugin tier cap (memory fix)', () {
    Directory makeProject(String? optionsYaml) {
      final tmp = Directory.systemTemp.createTempSync('saropa_plugin_cap_');
      addTearDown(() {
        try {
          tmp.deleteSync(recursive: true);
        } on Object {
          // Best-effort cleanup.
        }
      });
      if (optionsYaml != null) {
        File(
          '${tmp.path}/analysis_options.yaml',
        ).writeAsStringSync(optionsYaml);
      }
      return tmp;
    }

    // reloadRuntimeTierCapForPlugin reads Platform.environment directly and has no
    // env-override parameter, so an ambient SAROPA_TIER would mask the default it
    // is meant to verify. Assert the precondition loudly rather than pass silently.
    final ambientTier = Platform.environment['SAROPA_TIER']?.trim();
    final ambientUnset = ambientTier == null || ambientTier.isEmpty;

    test('plugin path defaults to essential when no tier is configured', () {
      expect(
        ambientUnset,
        isTrue,
        reason: 'unset SAROPA_TIER in the test environment to run this test',
      );
      final tmp = makeProject(null);

      reloadRuntimeTierCapForPlugin(tmp.path);

      expect(RuntimeTierCap.activeCap, RuleTier.essential);
      expect(RuntimeTierCap.activeCapLabel, 'essential');
      expect(
        RuntimeTierCap.ruleAllowedByCap(tiers.pedanticOnlyRules.first),
        isFalse,
      );
      expect(
        RuntimeTierCap.ruleAllowedByCap(tiers.essentialRules.first),
        isTrue,
      );
    });

    test('explicit yaml tier overrides the plugin default', () {
      expect(
        ambientUnset,
        isTrue,
        reason: 'unset SAROPA_TIER to run this test',
      );
      final tmp = makeProject('''
plugins:
  saropa_lints:
    runtime_tier: comprehensive
''');

      reloadRuntimeTierCapForPlugin(tmp.path);

      // The configured tier wins over the essential in-process default.
      expect(RuntimeTierCap.activeCap, RuleTier.comprehensive);
    });

    test('scan path stays uncapped when no tier is configured', () {
      final tmp = makeProject(null);

      // Empty env override = deterministic; the scan path passes no default cap,
      // so an unconfigured project runs full coverage out-of-process.
      reloadRuntimeTierCapFromProject(tmp.path, {});

      expect(RuntimeTierCap.activeCap, isNull);
      expect(
        RuntimeTierCap.ruleAllowedByCap(tiers.pedanticOnlyRules.first),
        isTrue,
      );
    });
  });
}
