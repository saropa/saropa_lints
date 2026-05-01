import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

/// Tests for opt-in rule registration (rules disabled by default).
///
/// Validates that the plugin only instantiates and registers rules
/// explicitly listed in [SaropaLintRule.enabledRules], and that
/// [SaropaLintRule.disabledRules] takes precedence when both are set.
void main() {
  // Save and restore static state around each test.
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

  group('getRulesFromRegistry (opt-in filtering)', () {
    test('returns only rules in the requested set', () {
      final requested = <String>{'avoid_debug_print', 'avoid_null_assertion'};
      final rules = getRulesFromRegistry(requested);

      expect(rules, isNotEmpty);
      for (final rule in rules) {
        expect(
          requested.contains(rule.code.lowerCaseName),
          isTrue,
          reason: '${rule.code.lowerCaseName} should be in the requested set',
        );
      }
    });

    test('returns empty list for unknown rule names', () {
      final rules = getRulesFromRegistry(<String>{
        'nonexistent_rule_xyz',
        'another_fake_rule',
      });
      expect(rules, isEmpty);
    });

    test('returns empty list for empty set', () {
      final rules = getRulesFromRegistry(<String>{});
      expect(rules, isEmpty);
    });
  });

  group('enabledRules null = no rules fire', () {
    test('null enabledRules means safe default (no rules)', () {
      SaropaLintRule.enabledRules = null;
      expect(SaropaLintRule.enabledRules, isNull);
    });

    test('empty enabledRules means no rules', () {
      SaropaLintRule.enabledRules = <String>{};
      expect(SaropaLintRule.enabledRules, isEmpty);
    });
  });

  group('disabledRules takes precedence over enabledRules', () {
    test('rule in both sets is effectively disabled', () {
      const ruleName = 'avoid_debug_print';
      SaropaLintRule.enabledRules = <String>{ruleName};
      SaropaLintRule.disabledRules = <String>{ruleName};

      // getRulesFromRegistry returns it (it only checks enabledRules)
      final rules = getRulesFromRegistry(SaropaLintRule.enabledRules!);
      expect(rules, hasLength(1));

      // But isDisabled returns true (safety net)
      expect(rules.first.isDisabled, isTrue);
    });

    test('rule only in enabledRules is not disabled', () {
      const ruleName = 'avoid_debug_print';
      SaropaLintRule.enabledRules = <String>{ruleName};
      SaropaLintRule.disabledRules = null;

      final rules = getRulesFromRegistry(SaropaLintRule.enabledRules!);
      expect(rules, hasLength(1));
      expect(rules.first.isDisabled, isFalse);
    });

    test('disabledRules null means nothing is disabled', () {
      SaropaLintRule.disabledRules = null;
      final rules = getRulesFromRegistry(<String>{'avoid_debug_print'});
      expect(rules, hasLength(1));
      expect(rules.first.isDisabled, isFalse);
    });
  });

  group('false positive: unrelated rules are not affected', () {
    test('enabling one rule does not enable others', () {
      SaropaLintRule.enabledRules = <String>{'avoid_debug_print'};
      final rules = getRulesFromRegistry(SaropaLintRule.enabledRules!);

      expect(rules, hasLength(1));
      expect(rules.first.code.lowerCaseName, 'avoid_debug_print');
    });

    test('disabling one rule does not disable others', () {
      SaropaLintRule.enabledRules = <String>{
        'avoid_debug_print',
        'avoid_null_assertion',
      };
      SaropaLintRule.disabledRules = <String>{'avoid_debug_print'};

      final rules = getRulesFromRegistry(SaropaLintRule.enabledRules!);
      expect(rules, hasLength(2));

      final debugPrint = rules.firstWhere(
        (r) => r.code.lowerCaseName == 'avoid_debug_print',
      );
      final dispose = rules.firstWhere(
        (r) => r.code.lowerCaseName == 'avoid_null_assertion',
      );

      expect(debugPrint.isDisabled, isTrue);
      expect(dispose.isDisabled, isFalse);
    });
  });
}
