import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/speech_to_text_rules.dart';

/// Instantiation-pin tests for speech_to_text lint rules.
///
/// Verifies code names and the problem-message contract (prefixed,
/// >200 chars, correctionMessage present). These pins fail fast if a rule's
/// code name or message contract regresses during a refactor.
void main() {
  group('SpeechToText Rules - Rule Instantiation', () {
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
      'RequireSpeechStopOnDisposeRule',
      'require_speech_stop_on_dispose',
      () => RequireSpeechStopOnDisposeRule(),
    );
  });

  group('SpeechToText Rules - Fix Presence', () {
    test('RequireSpeechStopOnDisposeRule has no fixGenerators', () {
      final rule = RequireSpeechStopOnDisposeRule();
      // The recognizer field name and dispose site vary per widget, so the
      // stop() call cannot be inserted mechanically; no quick fix.
      expect(rule.fixGenerators, isEmpty);
    });
  });
}
