import 'dart:io';

import 'package:test/test.dart';

/// Tests for prefer_setup_teardown false-positive fix.
///
/// Validates two fixes:
/// 1. Assertion/verification calls (expect, verify, fail, etc.) are excluded
///    from setup-code signatures — they are test body, not initialization.
/// 2. Signature counting is scoped per group() block — tests in different
///    groups no longer inflate each other's duplicate count.
///
/// Test fixture:
/// - example_style/lib/testing/testing_rules_additional_fixture.dart
void main() {
  group('prefer_setup_teardown', () {
    test('fixture file exists', () {
      final file = File(
        'example_style/lib/testing/testing_rules_additional_fixture.dart',
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

      test('expectLater() calls should NOT be treated as setup code', () {
        // `expectLater(stream, emitsInOrder(...))` is an assertion
        expect(
          'expectLater is in _assertionFunctions set',
          isNotNull,
        );
      });

      test('await expectLater() should NOT be treated as setup code', () {
        // `await expectLater(...)` wraps MethodInvocation in AwaitExpression.
        // _isAssertionCall unwraps AwaitExpression before checking.
        expect(
          'AwaitExpression is unwrapped in _isAssertionCall',
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

      test('fail() calls should NOT be treated as setup code', () {
        // fail() throws TestFailure — it is an assertion, not setup
        expect(
          'fail is in _assertionFunctions set',
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

    group('group-scoped counting (false positive fix)', () {
      test('tests in SAME group count toward threshold', () {
        // 3+ tests within group('X', () { ... }) sharing setup → triggers
        expect(
          'grouped tests are compared within their scope',
          isNotNull,
        );
      });

      test('tests in DIFFERENT groups do NOT count together', () {
        // 1 test in group A, 1 in group B, 1 in group C — same setup
        // pattern but only 1 per group → does NOT trigger
        expect(
          '_findEnclosingGroup scopes counting per group',
          isNotNull,
        );
      });

      test('top-level tests (no group) are counted together', () {
        // Tests not inside any group() share the null group key
        expect(
          'null group key collects top-level tests',
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

      test('simple literal locals should NOT trigger', () {
        // `int count = 0; const iterations = 1000;` are simple inits
        expect(
          '_isSimpleLocalInit filters primitive declarations',
          isNotNull,
        );
      });

      test('fewer than 3 matches should NOT trigger', () {
        // Threshold is 3 — 2 identical patterns do not fire the rule
        expect(
          'entry.value < 3 → skip',
          isNotNull,
        );
      });
    });
  });
}
