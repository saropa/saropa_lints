import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/google_fonts_rules.dart';

/// Instantiation-pin tests for google_fonts lint rules.
///
/// Verifies code names and the problem-message contract (prefixed,
/// >200 chars, correctionMessage present). These pins fail fast if a rule's
/// code name or message contract regresses during a refactor.
void main() {
  group('GoogleFonts Rules - Rule Instantiation', () {
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
      'RequireGoogleFontsFallbackRule',
      'require_google_fonts_fallback',
      () => RequireGoogleFontsFallbackRule(),
    );
  });

  group('GoogleFonts Rules - Fix Presence', () {
    test('RequireGoogleFontsFallbackRule has no fixGenerators', () {
      final rule = RequireGoogleFontsFallbackRule();
      // The fallback TextStyle the author wants is design-specific, so no
      // single replacement is correct; no quick fix.
      expect(rule.fixGenerators, isEmpty);
    });
  });
}
