import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

/// Instantiation pins for the MethodChannel instrumentation rules.
///
/// Fixture-verified behavior lives in
/// `example/lib/platform/require_method_channel_instrumented_fixture.dart`
/// and `example/lib/platform/prefer_method_channel_note_if_slow_fixture.dart`
/// (`expect_lint` comments); these tests pin metadata and tier registration.
void main() {
  group('Method Channel Rules - Rule Instantiation', () {
    group('RequireMethodChannelInstrumentedRule', () {
      test('rule metadata', () {
        final rule = RequireMethodChannelInstrumentedRule();
        expect(rule.code.lowerCaseName, 'require_method_channel_instrumented');
        expect(
          rule.code.problemMessage,
          contains('[require_method_channel_instrumented]'),
        );
        // Project convention: problem messages exceed 200 chars.
        expect(rule.code.problemMessage.length, greaterThan(200));
        expect(rule.code.correctionMessage, isNotNull);
        expect(rule.impact, LintImpact.info);
      });

      test('has a quick fix', () {
        final rule = RequireMethodChannelInstrumentedRule();
        expect(rule.fixGenerators, isNotEmpty);
      });

      test('registered in the comprehensive tier', () {
        expect(
          getRulesForTier('comprehensive'),
          contains('require_method_channel_instrumented'),
        );
      });
    });

    group('PreferMethodChannelNoteIfSlowRule', () {
      test('rule metadata', () {
        final rule = PreferMethodChannelNoteIfSlowRule();
        expect(rule.code.lowerCaseName, 'prefer_method_channel_note_if_slow');
        expect(
          rule.code.problemMessage,
          contains('[prefer_method_channel_note_if_slow]'),
        );
        // Project convention: problem messages exceed 200 chars.
        expect(rule.code.problemMessage.length, greaterThan(200));
        expect(rule.code.correctionMessage, isNotNull);
        expect(rule.impact, LintImpact.info);
      });

      test(
        'declares require_method_channel_instrumented as a related rule',
        () {
          final rule = PreferMethodChannelNoteIfSlowRule();
          expect(
            rule.relatedRules,
            contains('require_method_channel_instrumented'),
          );
        },
      );

      test('registered in the comprehensive tier', () {
        expect(
          getRulesForTier('comprehensive'),
          contains('prefer_method_channel_note_if_slow'),
        );
      });
    });
  });
}
