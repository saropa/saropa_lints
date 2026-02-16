import 'dart:io';

import 'package:test/test.dart';

/// Tests for require_error_case_tests false-positive fix.
///
/// Validates that expanded keyword detection covers defensive behavior
/// patterns (e.g. "returns zero when unattached", "handles safely")
/// without missing genuine happy-path-only test files.
///
/// Test fixture:
/// - example_style/lib/testing_best_practices/require_error_case_tests_fixture.dart
void main() {
  group('require_error_case_tests', () {
    test('fixture file exists', () {
      final file = File(
        'example_style/lib/testing_best_practices/'
        'require_error_case_tests_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });

    group('keyword detection', () {
      // Read the rule source to extract the _errorCaseKeywords set
      late String ruleSource;
      setUp(() {
        ruleSource = File(
          'lib/src/rules/testing_best_practices_rules.dart',
        ).readAsStringSync();
      });

      test('original keywords still present (regression)', () {
        const originalKeywords = [
          'throw',
          'error',
          'fail',
          'invalid',
          'exception',
          'null',
          'empty',
          'boundary',
          'edge',
          'negative',
          'fallback',
          'missing',
        ];
        for (final keyword in originalKeywords) {
          expect(
            ruleSource.contains("'$keyword'"),
            isTrue,
            reason:
                'Original keyword "$keyword" should still be '
                'in _errorCaseKeywords',
          );
        }
      });

      test('defensive behavior keywords present (false positive fix)', () {
        const defensiveKeywords = [
          'safely',
          'graceful',
          'default',
          'defensive',
        ];
        for (final keyword in defensiveKeywords) {
          expect(
            ruleSource.contains("'$keyword'"),
            isTrue,
            reason:
                'Defensive keyword "$keyword" should be '
                'in _errorCaseKeywords',
          );
        }
      });

      test('lifecycle/state keywords present', () {
        const lifecycleKeywords = ['dispose', 'closed', 'disconnect'];
        for (final keyword in lifecycleKeywords) {
          expect(
            ruleSource.contains("'$keyword'"),
            isTrue,
            reason:
                'Lifecycle keyword "$keyword" should be '
                'in _errorCaseKeywords',
          );
        }
      });

      test('failure condition keywords present', () {
        const failureKeywords = [
          'timeout',
          'cancel',
          'reject',
          'denied',
          'unauthorized',
        ];
        for (final keyword in failureKeywords) {
          expect(
            ruleSource.contains("'$keyword'"),
            isTrue,
            reason:
                'Failure keyword "$keyword" should be '
                'in _errorCaseKeywords',
          );
        }
      });

      test('boundary/validation keywords present', () {
        const boundaryKeywords = [
          'zero',
          'overflow',
          'malformed',
          'corrupt',
          'unavailable',
          'not found',
        ];
        for (final keyword in boundaryKeywords) {
          expect(
            ruleSource.contains("'$keyword'"),
            isTrue,
            reason:
                'Boundary keyword "$keyword" should be '
                'in _errorCaseKeywords',
          );
        }
      });

      test('keywords use Set.any for matching (not if-chain)', () {
        expect(
          ruleSource.contains('_errorCaseKeywords.any(firstArg.contains)'),
          isTrue,
          reason:
              'Should use _errorCaseKeywords.any() instead of '
              'chained if/contains',
        );
      });
    });

    group('false positive scenarios (fixture)', () {
      late String fixtureSource;
      setUp(() {
        fixtureSource = File(
          'example_style/lib/testing_best_practices/'
          'require_error_case_tests_fixture.dart',
        ).readAsStringSync();
      });

      test('BAD case exists for happy-path-only tests', () {
        expect(
          fixtureSource.contains('expect_lint: require_error_case_tests'),
          isTrue,
          reason: 'Fixture should have a BAD case that triggers the rule',
        );
      });

      test('GOOD case exists for throwsA matcher', () {
        expect(
          fixtureSource.contains('_good1213_throwsA'),
          isTrue,
          reason: 'Fixture should have a GOOD case with throwsA matcher',
        );
      });

      test('GOOD case exists for "safely" keyword', () {
        expect(
          fixtureSource.contains('_good1213_safely'),
          isTrue,
          reason:
              'Fixture should have a GOOD case for defensive '
              '"safely" keyword',
        );
      });

      test('GOOD case exists for "timeout" keyword', () {
        expect(
          fixtureSource.contains('_good1213_timeout'),
          isTrue,
          reason: 'Fixture should have a GOOD case for "timeout" keyword',
        );
      });

      test('GOOD case exists for "dispose" keyword', () {
        expect(
          fixtureSource.contains('_good1213_dispose'),
          isTrue,
          reason: 'Fixture should have a GOOD case for "dispose" keyword',
        );
      });

      test('GOOD case exists for "default" keyword', () {
        expect(
          fixtureSource.contains('_good1213_default'),
          isTrue,
          reason: 'Fixture should have a GOOD case for "default" keyword',
        );
      });
    });
  });
}
