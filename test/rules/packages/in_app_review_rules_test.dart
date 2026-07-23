import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/in_app_review_rules.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for 5 in_app_review lint rules.
///
/// Test fixtures: example_packages/lib/in_app_review/*
void main() {
  group('InAppReview Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.lowerCaseName, codeName);
        expect(rule.code.problemMessage, contains('[$codeName]'));
        expect(rule.code.problemMessage.length, greaterThan(200));
        expect(rule.code.correctionMessage, isNotNull);
      });
    }

    testRule(
      'InAppReviewMissingAvailabilityCheckRule',
      'in_app_review_missing_availability_check',
      () => InAppReviewMissingAvailabilityCheckRule(),
    );

    testRule(
      'InAppReviewButtonCallbackRequestRule',
      'in_app_review_button_callback_request',
      () => InAppReviewButtonCallbackRequestRule(),
    );

    testRule(
      'InAppReviewRequestInInitStateRule',
      'in_app_review_request_in_init_state',
      () => InAppReviewRequestInInitStateRule(),
    );

    testRule(
      'InAppReviewMissingStoreListingFallbackRule',
      'in_app_review_missing_store_listing_fallback',
      () => InAppReviewMissingStoreListingFallbackRule(),
    );

    testRule(
      'InAppReviewIosStoreListingMissingAppIdRule',
      'in_app_review_ios_store_listing_missing_app_id',
      () => InAppReviewIosStoreListingMissingAppIdRule(),
    );
  });

  group('InAppReview Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/in_app_review');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/in_app_review/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });
}
