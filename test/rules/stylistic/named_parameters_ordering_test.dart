// named_parameters_ordering: smoke-test the rule class for stable
// `LintCode` metadata strings. Real firing behavior is verified separately
// via the scan CLI against example/lib/stylistic/named_parameters_ordering_fixture.dart
// (see plans/tier_1_quick_wins/proposal_named_parameters_ordering.md).
library;

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/stylistic/named_parameters_ordering_rules.dart';

void main() {
  group('NamedParametersOrderingRule - Rule Instantiation', () {
    test('NamedParametersOrderingRule', () {
      final rule = NamedParametersOrderingRule();
      expect(rule.code.lowerCaseName, 'named_parameters_ordering');
      expect(
        rule.code.problemMessage,
        contains('[named_parameters_ordering]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });
}
