import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

/// Regression guards for `prefer_single_ticker_provider_state_mixin`.
///
/// This test focuses on false-positive boundaries documented in
/// `bugs/prefer_single_ticker_provider_state_mixin_false_positive_external_ticker_consumers.md`.
void main() {
  const ruleName = 'prefer_single_ticker_provider_state_mixin';
  const fixturePath =
      'example/lib/animation/prefer_single_ticker_provider_state_mixin_fixture.dart';

  group(
    'prefer_single_ticker_provider_state_mixin external vsync handoffs',
    () {
      test('is registered in allSaropaRules', () {
        final names = allSaropaRules.map((r) => r.code.lowerCaseName).toSet();
        expect(names.contains(ruleName), isTrue);
      });

      test('getRulesFromRegistry resolves the rule by name', () {
        final rules = getRulesFromRegistry(<String>{ruleName});
        expect(rules, hasLength(1));
        expect(rules.single.code.lowerCaseName, ruleName);
      });

      test('ships with recommended tier (cumulative)', () {
        final recommended = getRulesForTier('recommended');
        expect(
          recommended.contains(ruleName),
          isTrue,
          reason: '$ruleName should be available in recommended tier and above',
        );
      });

      test('fixture exists', () {
        expect(File(fixturePath).existsSync(), isTrue);
      });

      test('external helper with vsync: this has no expect_lint marker', () {
        final content = File(fixturePath).readAsStringSync();
        final start = content.indexOf('class _GoodExternalVsyncHandoff');
        final end = content.indexOf('class _GoodExternalVsyncHandoffInList');
        expect(start, greaterThan(-1));
        expect(end, greaterThan(start));

        final slice = content.substring(start, end);
        expect(
          slice.contains('// expect_lint: $ruleName'),
          isFalse,
          reason:
              'Single direct controller + external vsync handoff must not lint',
        );
      });

      test(
        'list-based external helpers with vsync: this have no expect_lint',
        () {
          final content = File(fixturePath).readAsStringSync();
          final start = content.indexOf(
            'class _GoodExternalVsyncHandoffInList',
          );
          final end = content.indexOf('// FALSE POSITIVES: Should NOT trigger');
          expect(start, greaterThan(-1));
          expect(end, greaterThan(start));

          final slice = content.substring(start, end);
          expect(
            slice.contains('// expect_lint: $ruleName'),
            isFalse,
            reason: 'Collection-based external vsync handoffs must not lint',
          );
        },
      );
    },
  );
}
