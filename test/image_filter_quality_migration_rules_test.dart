import 'package:saropa_lints/saropa_lints.dart' show
    comprehensiveOnlyRules,
    getRulesFromRegistry,
    LintImpact,
    recommendedOnlyRules,
    rulesWithFixes;
import 'package:saropa_lints/src/rules/widget/image_filter_quality_migration_rules.dart';
import 'package:test/test.dart';

/// Tests for image filter quality migration rules.
///
/// Detection logic is tested in image_filter_quality_detection_test.dart;
/// this file covers registration, tier, and Rule Instantiation metadata.
void main() {
  const codeName = 'prefer_image_filter_quality_medium';

  group('tier and registry', () {
    test('rule is in comprehensiveOnlyRules (opt-in stricter tier)', () {
      expect(comprehensiveOnlyRules.contains(codeName), isTrue);
    });

    test('rule is not a recommended-only add-on (use comprehensive / pedantic path)', () {
      expect(recommendedOnlyRules.contains(codeName), isFalse);
    });

    test('getRulesFromRegistry returns one rule for the name', () {
      final rules = getRulesFromRegistry({codeName});
      expect(rules, hasLength(1));
      expect(rules.single.code.lowerCaseName, codeName);
    });
  });

  group('Image Filter Quality Migration Rules - Rule Instantiation', () {
    test('PreferImageFilterQualityMediumRule', () {
      getRulesFromRegistry({codeName});
      final rule = PreferImageFilterQualityMediumRule();
      expect(rule.code.lowerCaseName, codeName);
      expect(
        rule.code.problemMessage,
        contains('[$codeName]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(80));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.fixGenerators, isNotEmpty);
      expect(rulesWithFixes.contains(codeName), isTrue);
      expect(rule.impact, LintImpact.low);
    });
  });
}
