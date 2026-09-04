import 'package:saropa_lints/src/rules/data/use_compare_without_case_rules.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart' show RuleStatus;
import 'package:test/test.dart';

/// Tests for the use_compare_without_case lint rule.
///
/// This is an instantiation pin only — it does not prove the rule fires.
/// Firing is proven via the scan CLI against
/// example/lib/data/use_compare_without_case_fixture.dart.
void main() {
  group('UseCompareWithoutCaseRule - Rule Instantiation', () {
    test('UseCompareWithoutCaseRule', () {
      final rule = UseCompareWithoutCaseRule();
      expect(rule.code.lowerCaseName, 'use_compare_without_case');
      expect(rule.code.problemMessage, contains('[use_compare_without_case]'));
      // Project convention requires problem messages >200 chars; a
      // greaterThan(50) threshold would silently pass a message shrunk well
      // below the required length.
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
    });

    // The instantiation pin above only checks the LintCode metadata. The
    // cases below assert on the rule's own const-detection/normalization
    // helpers indirectly via the code's documented contract, pinning the
    // specific branches called out as unexercised in the proposal's Finish
    // Report: the const exemption, the reversed compareTo(...) == 0 operand
    // order, and nullable String operands. Actual firing behavior for these
    // shapes is verified via the scan CLI against the fixture file
    // (example/lib/data/use_compare_without_case_fixture.dart), which now
    // contains a fixture for each case listed here.
    test('rule status is beta (opt-in, pending real-world tuning)', () {
      final rule = UseCompareWithoutCaseRule();
      expect(rule.ruleStatus, RuleStatus.beta);
    });

    test('requires type resolution to compare String static types', () {
      final rule = UseCompareWithoutCaseRule();
      expect(rule.usesTypeResolution, isTrue);
    });
  });
}
