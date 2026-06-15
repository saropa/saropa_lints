import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/envied_rules.dart';

/// Instantiation-pin tests for envied lint rules.
///
/// Verifies code names and the problem-message contract (prefixed,
/// >200 chars, correctionMessage present). These pins fail fast if a rule's
/// code name or message contract regresses during a refactor.
void main() {
  group('Envied Rules - Rule Instantiation', () {
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
      'RequireEnviedObfuscationRule',
      'require_envied_obfuscation',
      () => RequireEnviedObfuscationRule(),
    );
  });

  group('Envied Rules - Fix Presence', () {
    test('RequireEnviedObfuscationRule has no fixGenerators', () {
      final rule = RequireEnviedObfuscationRule();
      // Obfuscation placement depends on whether the secret is class- or
      // field-scoped, so the correct edit is caller-defined; no quick fix.
      expect(rule.fixGenerators, isEmpty);
    });
  });
}
