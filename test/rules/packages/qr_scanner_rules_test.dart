import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/qr_scanner_rules.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for 3 QR Scanner lint rules.
///
/// Test fixtures: example_packages/lib/qr_scanner/*
void main() {
  group('Qr Scanner Rules - Rule Instantiation', () {
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
      'RequireQrScanFeedbackRule',
      'require_qr_scan_feedback',
      () => RequireQrScanFeedbackRule(),
    );

    testRule(
      'AvoidQrScannerAlwaysActiveRule',
      'avoid_qr_scanner_always_active',
      () => AvoidQrScannerAlwaysActiveRule(),
    );

    testRule(
      'RequireQrContentValidationRule',
      'require_qr_content_validation',
      () => RequireQrContentValidationRule(),
    );
  });

  group('QR Scanner Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/qr_scanner');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/qr_scanner/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });
}
