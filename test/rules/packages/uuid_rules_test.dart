import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/uuid_rules.dart';

/// Instantiation-pin tests for uuid lint rules.
///
/// Verifies code names and the problem-message contract (prefixed,
/// >200 chars, correctionMessage present). These pins fail fast if a rule's
/// code name or message contract regresses during a refactor.
void main() {
  group('Uuid Rules - Rule Instantiation', () {
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

    testRule('PreferUuidV4Rule', 'prefer_uuid_v4', () => PreferUuidV4Rule());
  });

  group('Uuid Rules - Fix Presence', () {
    test('PreferUuidV4Rule has fixGenerators', () {
      final rule = PreferUuidV4Rule();
      // v1/v6 → v4 is a deterministic method-name swap, so a quick fix exists.
      expect(rule.fixGenerators, isNotEmpty);
    });
  });
}
