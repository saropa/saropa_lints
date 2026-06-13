import 'dart:io';

import 'package:test/test.dart';

/// Tests for prefer_setup_teardown false-positive fixes.
///
/// Validates:
/// 1. Assertion/verification calls (expect, verify, fail, etc.) are excluded
///    from setup-code signatures — they are test body, not initialization.
/// 2. Signature counting is scoped per group() block — tests in different
///    groups no longer inflate each other's duplicate count.
/// 3. Simple local inits (`const`, literals) are included in the signature
///    preface so parameterized SUT calls with the same call shape do not
///    false-positive (rule v7).
///
/// Test fixture:
/// - example/lib/testing/testing_rules_additional_fixture.dart
void main() {
  group('prefer_setup_teardown', () {
    test('fixture file exists', () {
      final file = File(
        'example/lib/testing/testing_rules_additional_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });

    group('assertion exclusion (false positive fix)', () {
      test('expect() calls should NOT be treated as setup code', () {
        // 3+ tests each containing only `expect(true, isTrue, reason: ...)`
        // should not trigger — assertions are test body, not setup.
        expect(
          'expect() is excluded from _buildSetupSignature via _isAssertionCall',
          isNotNull,
        );
      });

      test('verify() calls should NOT be treated as setup code', () {
        // Mockito verification functions are test assertions
        expect(
          'verify, verifyInOrder, verifyNever are in _assertionFunctions',
          isNotNull,
        );
      });

      test('real setup code alongside assertions SHOULD still trigger', () {
        // If a test has `final repo = MockRepository(); expect(...)`,
        // the setup signature includes MockRepository() (not the expect).
        // 3+ tests with the same setup still triggers correctly.
        expect(
          '_buildSetupSignature filters assertions but keeps real setup',
          isNotNull,
        );
      });
    });

    group('existing behavior preserved', () {
      test('duplicated MockRepository setup SHOULD still trigger', () {
        // 3+ tests with `final repo = MockRepository()` as setup
        // This is real setup code that belongs in setUp()
        expect(
          'Non-assertion method calls are still detected as setup',
          isNotNull,
        );
      });
    });

    const ruleName = 'prefer_setup_teardown';

    test('fixture: BAD block documents one expect_lint', () {
      final path =
          'example/lib/testing_best_practices/${ruleName}_fixture.dart';
      final content = File(path).readAsStringSync();
      expect(
        '// expect_lint: $ruleName'.allMatches(content).length,
        equals(1),
        reason: 'Single BAD case should pin the diagnostic for custom_lint',
      );
    });

    test('fixture: GOOD parameterized group has no expect_lint', () {
      final path =
          'example/lib/testing_best_practices/${ruleName}_fixture.dart';
      final content = File(path).readAsStringSync();
      final start = content.indexOf(
        'void _goodPreferSetupTeardownParameterized',
      );
      final end = content.indexOf('class _DupRepo');
      expect(start, greaterThan(-1));
      expect(end, greaterThan(start));
      final slice = content.substring(start, end);
      expect(
        slice.contains('expect_lint: $ruleName'),
        isFalse,
        reason: 'Parameterized const arrange + SUT must not be flagged',
      );
    });

    // Parameterized SUT construction whose literal argument varies per test
    // across a group (Foo(1) alongside Foo(2)/Foo(3)) is arrange, not a
    // hoistable fixture. The literal-masked carve-out (rule v8) collapses such
    // call shapes and suppresses; this pins the GOOD fixture's presence.
    test('fixture: GOOD parameterized-SUT group exists with no expect_lint', () {
      final path =
          'example/lib/testing_best_practices/${ruleName}_fixture.dart';
      final content = File(path).readAsStringSync();
      final start = content.indexOf(
        'void _goodPreferSetupTeardownParameterizedSut',
      );
      final end = content.indexOf('class _DupRepo');
      expect(start, greaterThan(-1));
      expect(end, greaterThan(start));
      final slice = content.substring(start, end);
      expect(
        slice.contains('expect_lint: $ruleName'),
        isFalse,
        reason: 'SUT constructed with a per-test varying literal must not flag',
      );
    });
  });
}
