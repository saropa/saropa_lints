import 'package:saropa_lints/src/rules/data/use_compare_without_case_rules.dart';
import 'package:test/test.dart';

/// Tests for the use_compare_without_case lint rule.
///
/// This is an instantiation pin only — it does not prove the rule fires.
/// Firing is proven via the scan CLI against
/// example/lib/data/use_compare_without_case_fixture.dart (see the rule's
/// implementation notes in plans/tier_1_quick_wins/).
void main() {
  group('UseCompareWithoutCaseRule - Rule Instantiation', () {
    test('UseCompareWithoutCaseRule', () {
      final rule = UseCompareWithoutCaseRule();
      expect(rule.code.lowerCaseName, 'use_compare_without_case');
      expect(rule.code.problemMessage, contains('[use_compare_without_case]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });
}
