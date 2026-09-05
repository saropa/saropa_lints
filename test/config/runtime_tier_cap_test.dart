/// Module overview (comment coverage pass).
/// comment-coverage: module overview (batch).
///
/// Analyzer-backed tests for `runtime_tier_cap_test` (runtime tier cap).
///
/// Uses `// LINT` markers and `example/` fixtures per CONTRIBUTING.md.
library;

import 'dart:convert';
import 'dart:io';

import 'package:saropa_lints/src/config/runtime_tier_cap.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart' show RuleTier;
import 'package:saropa_lints/src/tiers.dart' as tiers;
import 'package:test/test.dart';

import '../support/safe_delete.dart';

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

    // WP3 regression test (PLAN_ext_ui_dart_deferred.md): the Config file tab
    // (rulePacksWebviewProvider.ts) offers a SEPARATE `runtime_tier` select
    // that writes top-level `runtime_tier:` into analysis_options_custom.yaml
    // — distinct from the `saropa_tier` select. Before this fix the regex here
    // only matched the literal `saropa_tier`, so a value written via the
    // `runtime_tier` select was parsed as `null` (silently dropped, no
    // deprecation warning, no effect) even though the extension had written
    // it to disk. This is a POSITIVE test — it asserts the real config value
    // actually flows through the parser, not just that null/absent input is
    // handled (see MEMORY.md: "Parsers need positive tests").
    test('parses top-level runtime_tier (Config file tab writes this key)', () {
      expect(
        parseSaropaTierFromCustomYaml('runtime_tier: comprehensive\n'),
        'comprehensive',
      );
    });

    test('parses quoted top-level runtime_tier', () {
      expect(
        parseSaropaTierFromCustomYaml("runtime_tier: 'pedantic'\n"),
        'pedantic',
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

  // Shared parity fixtures with extension/src/test/config/tierConfig.test.ts
  // — both suites assert the same expected tier for the same yaml input, so
  // the Dart and TS regex-based block parsers can't silently drift apart.
  // See test/fixtures/tier_yaml_parser_cases.json's own header comment.
  group('parseSaropaTierFromPluginBlock (shared fixture parity)', () {
    final fixtureFile = File('test/fixtures/tier_yaml_parser_cases.json');
    final fixture =
        jsonDecode(fixtureFile.readAsStringSync()) as Map<String, dynamic>;
    final cases = fixture['cases'] as List<dynamic>;

    for (final raw in cases) {
      final c = raw as Map<String, dynamic>;
      test(c['name'] as String, () {
        expect(
          parseSaropaTierFromPluginBlock(c['yaml'] as String),
          c['expected'] as String?,
        );
      });
    }
  });

  group('RuntimeTierCap', () {
    test('SAROPA_TIER caps pedantic-only rules off', () {
      final tmp = Directory.systemTemp.createTempSync('saropa_tier_cap_');
      // Retry-tolerant cleanup: Windows file handles can linger after tests
      addTearDown(() => safeDeleteDir(tmp));

      File('${tmp.path}/analysis_options.yaml').writeAsStringSync('''
plugins:
  saropa_lints:
    diagnostics:
      avoid_unguarded_debug: true
''');

      final pedanticOnly = tiers.pedanticOnlyRules.first;
      final essentialRule = tiers.essentialRules.first;
      expect(tiers.essentialRules.contains(pedanticOnly), isFalse);

      reloadRuntimeTierCapFromProject(tmp.path, {'SAROPA_TIER': 'essential'});
      expect(RuntimeTierCap.activeCap, RuleTier.essential);
      expect(RuntimeTierCap.ruleAllowedByCap(pedanticOnly), isFalse);
      expect(RuntimeTierCap.ruleAllowedByCap(essentialRule), isTrue);
      expect(RuntimeTierCap.ruleAllowedByCap('avoid_unguarded_debug'), isFalse);
    });

    // WP3 end-to-end pin: top-level `runtime_tier:` in analysis_options_custom.yaml
    // is now PARSED (see parseSaropaTierFromCustomYaml above — no longer a
    // silent no-op), but by design it still does NOT resolve the active cap:
    // analysis_options.yaml's plugins.saropa_lints block remains the sole
    // source of truth (doc comment atop this file). This test asserts BOTH
    // halves of that contract in one place so a future change can't silently
    // start honoring the deprecated key without a deliberate test update —
    // the plugin-block tier below must still win even though the custom file
    // also sets a (different) tier.
    test(
      'top-level runtime_tier in custom yaml is parsed but does not override '
      'the plugins.saropa_lints tier',
      () {
        final tmp = Directory.systemTemp.createTempSync(
          'saropa_runtime_tier_custom_',
        );
        addTearDown(() => safeDeleteDir(tmp));

        File('${tmp.path}/analysis_options.yaml').writeAsStringSync('''
plugins:
  saropa_lints:
    runtime_tier: essential
''');
        // Deliberately a DIFFERENT tier than the plugin block, so the test can
        // tell whether this deprecated key silently won (it must not).
        File(
          '${tmp.path}/analysis_options_custom.yaml',
        ).writeAsStringSync('runtime_tier: pedantic\n');

        reloadRuntimeTierCapFromProject(tmp.path, {});

        // The plugin-block tier (essential) wins; the custom-yaml runtime_tier
        // (pedantic) is recognized by the parser (proven above) but has no
        // effect on resolution — matching saropa_tier's existing deprecation
        // contract.
        expect(RuntimeTierCap.activeCap, RuleTier.essential);
      },
    );
  });

  // The in-process analyzer plugin must NOT run the full enabled rule set, or the
  // analysis server retains the whole project's resolved model and grows to a
  // multi-GB OOM hang. These tests pin the fix: the plugin path defaults to the
  // essential cap when nothing is configured, an explicit tier still overrides
  // that default, and the out-of-process scan path stays uncapped.
  group('in-process plugin tier cap (memory fix)', () {
    Directory makeProject(String? optionsYaml) {
      final tmp = Directory.systemTemp.createTempSync('saropa_plugin_cap_');
      addTearDown(() => safeDeleteDir(tmp));
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
