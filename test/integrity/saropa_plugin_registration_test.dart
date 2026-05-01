import 'package:analysis_server_plugin/registry.dart';
import 'package:analysis_server_plugin/src/correction/fix_generators.dart'
    show ProducerGenerator;
import 'package:analyzer/analysis_rule/analysis_rule.dart'
    show AbstractAnalysisRule;
import 'package:analyzer/error/error.dart' show DiagnosticCode, LintCode;
import 'package:analyzer/src/lint/config.dart' show RuleConfig;
import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

/// Captures registrations without touching the global analyzer rule registry.
final class _CaptureRegistry implements PluginRegistry {
  final List<AbstractAnalysisRule> lintRules = <AbstractAnalysisRule>[];
  final List<(LintCode, ProducerGenerator)> fixes =
      <(LintCode, ProducerGenerator)>[];

  @override
  Iterable<AbstractAnalysisRule> enabled(Map<String, RuleConfig> ruleConfigs) =>
      lintRules;

  @override
  void registerAssist(ProducerGenerator generator) {}

  @override
  void registerFixForRule(DiagnosticCode code, ProducerGenerator generator) {
    if (code is LintCode) {
      fixes.add((code, generator));
    }
  }

  @override
  void registerLintRule(AbstractAnalysisRule rule) {
    lintRules.add(rule);
  }

  @override
  void registerWarningRule(AbstractAnalysisRule rule) {}
}

void main() {
  Set<String>? savedEnabled;
  Set<String>? savedDisabled;

  setUp(() {
    savedEnabled = SaropaLintRule.enabledRules;
    savedDisabled = SaropaLintRule.disabledRules;
  });

  tearDown(() {
    SaropaLintRule.enabledRules = savedEnabled;
    SaropaLintRule.disabledRules = savedDisabled;
  });

  group('registerSaropaLintRules', () {
    // Semantics changed (fatal-bug fix): registerSaropaLintRules now
    // registers every known rule unconditionally. The per-rule enable
    // gate has moved to SaropaContext._wrapCallback (visitor-entry time).
    //
    // Rationale: the `analysis_server_plugin` API calls `Plugin.register`
    // synchronously in the `PluginServer` constructor, before `start()`,
    // before the communication channel, before any context-root info.
    // At register time the plugin cannot know the consumer's project root
    // and therefore cannot know which rules are enabled. The previous
    // design early-returned here when `enabledRules` was null/empty — which
    // silently killed every rule for consumers whose `Directory.current` at
    // plugin-start was not the project root (e.g. every VS Code user who
    // opened their workspace via the file picker rather than `code .`
    // from the project folder).

    test('registers all known rules when enabledRules is null', () {
      SaropaLintRule.enabledRules = null;
      SaropaLintRule.disabledRules = null;
      final cap = _CaptureRegistry();
      registerSaropaLintRules(cap);
      // Should register every rule the factory map knows about (~2100).
      // Exact count varies as rules are added — assert "plenty" instead
      // of a brittle absolute.
      expect(
        cap.lintRules.length,
        greaterThan(500),
        reason:
            'All rules must register at Plugin.register time; the enable '
            'gate moved to _wrapCallback. See bug: plugin silent for all '
            'consumers whose cwd differed from project root.',
      );
    });

    test('registers all known rules when enabledRules is empty', () {
      SaropaLintRule.enabledRules = <String>{};
      SaropaLintRule.disabledRules = null;
      final cap = _CaptureRegistry();
      registerSaropaLintRules(cap);
      expect(cap.lintRules.length, greaterThan(500));
    });

    test('registers fixes for rules that declare them', () {
      SaropaLintRule.enabledRules = null;
      SaropaLintRule.disabledRules = null;
      final cap = _CaptureRegistry();
      registerSaropaLintRules(cap);
      expect(cap.fixes, isNotEmpty);
    });

    test('skips rule listed in disabledRules by canonical name', () {
      const ruleName = 'avoid_debug_print';
      SaropaLintRule.enabledRules = null;
      SaropaLintRule.disabledRules = {ruleName};
      final cap = _CaptureRegistry();
      registerSaropaLintRules(cap);
      final matching = cap.lintRules.where((r) => r.name == ruleName).toList();
      expect(
        matching,
        isEmpty,
        reason: 'disabledRules must still suppress registration',
      );
    });

    test(
      'skips rule when disabled only via configAliases (false positive guard)',
      () {
        const canonical = 'require_riverpod_lint';
        const alias = 'require_riverpod_lint_package';
        SaropaLintRule.enabledRules = null;
        SaropaLintRule.disabledRules = {alias};
        expect(
          getRulesFromRegistry({canonical}).single.isDisabled,
          isTrue,
          reason: 'alias in disabledRules must mark rule disabled',
        );
        final cap = _CaptureRegistry();
        registerSaropaLintRules(cap);
        final matching = cap.lintRules
            .where((r) => r.name == canonical)
            .toList();
        expect(matching, isEmpty);
      },
    );

    test(
      'unknown names in enabledRules do not block registration of known rules',
      () {
        // enabledRules is now consulted at _wrapCallback time, not here.
        // Unknown names in the set are simply never matched; they have no
        // effect at register time.
        SaropaLintRule.enabledRules = {
          'avoid_debug_print',
          'nonexistent_rule_xyz_12345',
        };
        SaropaLintRule.disabledRules = null;
        final cap = _CaptureRegistry();
        registerSaropaLintRules(cap);
        expect(cap.lintRules.any((r) => r.name == 'avoid_debug_print'), isTrue);
        expect(
          cap.lintRules.any((r) => r.name == 'nonexistent_rule_xyz_12345'),
          isFalse,
        );
      },
    );
  });
}
