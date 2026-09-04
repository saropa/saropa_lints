// named_parameters_ordering: smoke-test the rule class for stable
// `LintCode` metadata strings. Firing behavior against
// example/lib/stylistic/named_parameters_ordering_fixture.dart is covered by
// the fixture's `expect_lint` markers, which the project's fixture-based
// integrity checks validate.
library;

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/stylistic/named_parameters_ordering_rules.dart';

void main() {
  group('NamedParametersOrderingRule - Rule Instantiation', () {
    test('NamedParametersOrderingRule', () {
      final rule = NamedParametersOrderingRule();
      expect(rule.code.lowerCaseName, 'named_parameters_ordering');
      expect(rule.code.problemMessage, contains('[named_parameters_ordering]'));
      // Project-wide rule: problem messages must exceed 200 chars total
      // (CLAUDE.md "Problem Message Requirements") so they carry enough
      // context to stand alone in an IDE tooltip without truncation.
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });
}
