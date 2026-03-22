import 'package:analysis_server_plugin/registry.dart';
import 'package:analysis_server_plugin/src/correction/fix_generators.dart'
    show ProducerGenerator;
import 'package:analyzer/analysis_rule/analysis_rule.dart'
    show AbstractAnalysisRule;
import 'package:analyzer/error/error.dart' show LintCode;
import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

/// Captures registrations without touching the global analyzer rule registry.
final class _CaptureRegistry implements PluginRegistry {
  final List<AbstractAnalysisRule> lintRules = <AbstractAnalysisRule>[];
  final List<(LintCode, ProducerGenerator)> fixes =
      <(LintCode, ProducerGenerator)>[];

  @override
  void registerAssist(ProducerGenerator generator) {}

  @override
  void registerFixForRule(LintCode code, ProducerGenerator generator) {
    fixes.add((code, generator));
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
    test('no-op when enabledRules is null', () {
      SaropaLintRule.enabledRules = null;
      final cap = _CaptureRegistry();
      registerSaropaLintRules(cap);
      expect(cap.lintRules, isEmpty);
    });

    test('no-op when enabledRules is empty', () {
      SaropaLintRule.enabledRules = <String>{};
      final cap = _CaptureRegistry();
      registerSaropaLintRules(cap);
      expect(cap.lintRules, isEmpty);
    });

    test('registers enabled rule and fixes', () {
      const ruleName = 'avoid_debug_print';
      SaropaLintRule.enabledRules = {ruleName};
      SaropaLintRule.disabledRules = null;
      expect(getRulesFromRegistry(SaropaLintRule.enabledRules!), isNotEmpty);
      final cap = _CaptureRegistry();
      registerSaropaLintRules(cap);
      expect(cap.lintRules, isNotEmpty);
      expect(cap.lintRules.single.name, ruleName);
      expect(cap.fixes, isNotEmpty);
    });

    test('skips rule listed in disabledRules by canonical name', () {
      const ruleName = 'avoid_debug_print';
      SaropaLintRule.enabledRules = {ruleName};
      SaropaLintRule.disabledRules = {ruleName};
      final cap = _CaptureRegistry();
      registerSaropaLintRules(cap);
      expect(cap.lintRules, isEmpty);
    });

    test(
      'skips rule when disabled only via configAliases (false positive guard)',
      () {
        const canonical = 'require_riverpod_lint';
        const alias = 'require_riverpod_lint_package';
        SaropaLintRule.enabledRules = {canonical};
        SaropaLintRule.disabledRules = {alias};
        expect(
          getRulesFromRegistry({canonical}).single.isDisabled,
          isTrue,
          reason: 'alias in disabledRules must mark rule disabled',
        );
        final cap = _CaptureRegistry();
        registerSaropaLintRules(cap);
        expect(cap.lintRules, isEmpty);
      },
    );

    test('unknown enabled names do not register or throw', () {
      SaropaLintRule.enabledRules = {
        'avoid_debug_print',
        'nonexistent_rule_xyz_12345',
      };
      SaropaLintRule.disabledRules = null;
      final cap = _CaptureRegistry();
      registerSaropaLintRules(cap);
      expect(cap.lintRules, hasLength(1));
      expect(cap.lintRules.single.name, 'avoid_debug_print');
    });

    test('only unknown names yields no registrations (before state)', () {
      SaropaLintRule.enabledRules = {'totally_unknown_lint_abc'};
      SaropaLintRule.disabledRules = null;
      final cap = _CaptureRegistry();
      registerSaropaLintRules(cap);
      expect(cap.lintRules, isEmpty);
      expect(cap.fixes, isEmpty);
    });
  });
}
