import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/receive_sharing_intent_rules.dart';
import '../../helpers/fixture_discovery.dart';

/// Instantiation-pin tests for the 3 receive_sharing_intent lint rules.
///
/// Test fixtures: example_packages/lib/receive_sharing_intent/*
void main() {
  group('ReceiveSharingIntent Rules - Rule Instantiation', () {
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
      'ReceiveSharingIntentMissingInitialMediaRule',
      'rsi_missing_initial_media',
      () => ReceiveSharingIntentMissingInitialMediaRule(),
    );
    testRule(
      'ReceiveSharingIntentMissingResetRule',
      'rsi_missing_reset_after_initial_media',
      () => ReceiveSharingIntentMissingResetRule(),
    );
    testRule(
      'ReceiveSharingIntentUnfilteredTypeRule',
      'rsi_unfiltered_shared_media_type',
      () => ReceiveSharingIntentUnfilteredTypeRule(),
    );
  });

  group('ReceiveSharingIntent Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/receive_sharing_intent');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/receive_sharing_intent/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });
}
