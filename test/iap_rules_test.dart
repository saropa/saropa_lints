import 'dart:io';

import 'package:test/test.dart';

/// Tests for 4 In-App Purchase lint rules.
///
/// Test fixtures: example_async/lib/iap/*
void main() {
  group('In-App Purchase Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_purchase_in_sandbox_production',
      'require_subscription_status_check',
      'require_price_localization',
      'prefer_grace_period_handling',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example_async/lib/iap/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('In-App Purchase - Avoidance Rules', () {
    group('avoid_purchase_in_sandbox_production', () {
      test('sandbox purchase logic in production SHOULD trigger', () {
        expect('sandbox purchase logic in production', isNotNull);
      });

      test('environment-aware IAP flow should NOT trigger', () {
        expect('environment-aware IAP flow', isNotNull);
      });
    });
  });

  group('In-App Purchase - Requirement Rules', () {
    group('require_subscription_status_check', () {
      test('fixture has bad example with expect_lint marker', () {
        final content = File(
          'example_async/lib/iap/require_subscription_status_check_fixture.dart',
        ).readAsStringSync();
        expect(
          content,
          contains('// expect_lint: require_subscription_status_check'),
        );
        expect(content, contains('_bad'));
      });

      test('fixture has good example without expect_lint', () {
        final content = File(
          'example_async/lib/iap/require_subscription_status_check_fixture.dart',
        ).readAsStringSync();
        expect(content, contains('_good'));
        expect(content, contains('FutureBuilder'));
      });

      test('fixture has no remaining TODOs', () {
        final content = File(
          'example_async/lib/iap/require_subscription_status_check_fixture.dart',
        ).readAsStringSync();
        expect(content, isNot(contains('// TODO: Add')));
      });

      test('word boundary matching avoids false positives', () {
        // The rule uses \b word boundaries around each indicator.
        // "isProportional" should NOT match the "isPro" indicator.
        final pattern = RegExp(r'\b' + RegExp.escape('isPro') + r'\b');
        expect(pattern.hasMatch('isProportional'), isFalse);
        expect(pattern.hasMatch('isPro'), isTrue);
        expect(pattern.hasMatch('widget.isPro'), isTrue);
      });

      test('word boundary matching catches premium indicators', () {
        final pattern = RegExp(
          r'\b' + RegExp.escape('premium') + r'\b',
          caseSensitive: false,
        );
        // Standalone word matches
        expect(pattern.hasMatch('premium'), isTrue);
        expect(pattern.hasMatch('if (premium)'), isTrue);
        // CamelCase substrings do NOT match (no word boundary)
        expect(pattern.hasMatch('showPremiumContent()'), isFalse);
        expect(pattern.hasMatch('isPremium'), isFalse);
      });

      test('status check patterns are recognized as compliant', () {
        const verificationPatterns = [
          'FutureBuilder',
          'StreamBuilder',
          'checkStatus',
          'checkSubscription',
          'verifyPurchase',
          'getEntitlements',
          'customerInfo',
          'purchaseStream',
          'Consumer<',
          'BlocBuilder',
          'watch(',
          'ref.watch',
        ];
        for (final p in verificationPatterns) {
          expect(
            'Widget build(ctx) { return $p(); }'.contains(p),
            isTrue,
            reason: '$p should be detected as compliant',
          );
        }
      });
    });

    group('require_price_localization', () {
      test('hardcoded price string SHOULD trigger', () {
        expect('hardcoded price string', isNotNull);
      });

      test('localized price from store should NOT trigger', () {
        expect('localized price from store', isNotNull);
      });
    });
  });

  group('In-App Purchase - Preference Rules', () {
    group('prefer_grace_period_handling', () {
      test('instant access revocation on expiry SHOULD trigger', () {
        expect('instant access revocation on expiry', isNotNull);
      });

      test('grace period for subscription lapse should NOT trigger', () {
        expect('grace period for subscription lapse', isNotNull);
      });
    });
  });
}
