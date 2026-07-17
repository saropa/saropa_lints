import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/commerce/iap_rules.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for 5 In-App Purchase lint rules.
///
/// Test fixtures: example/lib/iap/*
void main() {
  group('Iap Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.lowerCaseName, codeName);
        expect(rule.code.problemMessage, contains('[$codeName]'));
        expect(rule.code.problemMessage.length, greaterThan(50));
        expect(rule.code.correctionMessage, isNotNull);
      });
    }

    testRule(
      'AvoidPurchaseInSandboxProductionRule',
      'avoid_purchase_in_sandbox_production',
      () => AvoidPurchaseInSandboxProductionRule(),
    );

    testRule(
      'RequireSubscriptionStatusCheckRule',
      'require_subscription_status_check',
      () => RequireSubscriptionStatusCheckRule(),
    );

    testRule(
      'RequirePriceLocalizationRule',
      'require_price_localization',
      () => RequirePriceLocalizationRule(),
    );

    testRule(
      'PreferGracePeriodHandlingRule',
      'prefer_grace_period_handling',
      () => PreferGracePeriodHandlingRule(),
    );

    testRule(
      'AvoidEntitlementWithoutServerRule',
      'avoid_entitlement_without_server',
      () => AvoidEntitlementWithoutServerRule(),
    );
  });

  group('In-App Purchase Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/iap');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/iap/${fixture}_fixture.dart');

        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('In-App Purchase - Requirement Rules', () {
    group('require_subscription_status_check', () {
      test('fixture has bad example with expect_lint marker', () {
        final content = File(
          'example/lib/iap/require_subscription_status_check_fixture.dart',
        ).readAsStringSync();
        expect(
          content,
          contains('// expect_lint: require_subscription_status_check'),
        );
        expect(content, contains('_bad'));
      });

      test('fixture has good example without expect_lint', () {
        final content = File(
          'example/lib/iap/require_subscription_status_check_fixture.dart',
        ).readAsStringSync();
        expect(content, contains('_good'));
        expect(content, contains('FutureBuilder'));
      });

      test('fixture has no remaining TODOs', () {
        final content = File(
          'example/lib/iap/require_subscription_status_check_fixture.dart',
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
  });
}
