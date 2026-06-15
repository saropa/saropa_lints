import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/openai_rules.dart';

/// Instantiation-pin tests for openai lint rules.
///
/// Verifies code names and the problem-message contract (prefixed,
/// >200 chars, correctionMessage present). These pins fail fast if a rule's
/// code name or message contract regresses during a refactor.
void main() {
  group('OpenAI Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.lowerCaseName, codeName);
        expect(
          rule.code.problemMessage,
          contains('[$codeName]'),
          reason: 'problem message must start with [$codeName] prefix',
        );
        expect(
          rule.code.problemMessage.length,
          greaterThan(200),
          reason: 'problem message must be >200 chars',
        );
        expect(
          rule.code.correctionMessage,
          isNotNull,
          reason: 'correctionMessage must be provided',
        );
      });
    }

    testRule(
      'AvoidOpenaiKeyInCodeRule',
      'avoid_openai_key_in_code',
      () => AvoidOpenaiKeyInCodeRule(),
    );

    testRule(
      'RequireOpenaiErrorHandlingRule',
      'require_openai_error_handling',
      () => RequireOpenaiErrorHandlingRule(),
    );
  });

  group('OpenAI Rules - Fix Presence', () {
    test('AvoidOpenaiKeyInCodeRule has no fixGenerators', () {
      final rule = AvoidOpenaiKeyInCodeRule();
      // The secure source for the key (env var, secret store) is project
      // specific, so the literal cannot be auto-replaced; no quick fix.
      expect(rule.fixGenerators, isEmpty);
    });

    test('RequireOpenaiErrorHandlingRule has no fixGenerators', () {
      final rule = RequireOpenaiErrorHandlingRule();
      // The recovery action for a failed call is caller-defined, so no
      // generic try/catch body can be inserted; no quick fix.
      expect(rule.fixGenerators, isEmpty);
    });
  });
}
