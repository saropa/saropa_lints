import 'package:saropa_lints/saropa_lints.dart' show LintImpact;
import 'package:saropa_lints/src/rules/widget/image_filter_quality_migration_rules.dart';
import 'package:test/test.dart';

/// Tests for image filter quality migration rules.
///
/// Detection logic is tested in image_filter_quality_detection_test.dart;
/// this file covers the convention-required Rule Instantiation group.
void main() {
  group('Image Filter Quality Migration Rules - Rule Instantiation', () {
    test('PreferImageFilterQualityMediumRule', () {
      final rule = PreferImageFilterQualityMediumRule();
      expect(rule.code.lowerCaseName, 'prefer_image_filter_quality_medium');
      expect(
        rule.code.problemMessage,
        contains('[prefer_image_filter_quality_medium]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(80));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.fixGenerators, isNotEmpty);
      expect(rule.impact, LintImpact.low);
    });
  });
}
