import 'dart:io';

import 'package:saropa_lints/src/rules/packages/sqflite_rules.dart';
import 'package:test/test.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for 2 Sqflite lint rules.
///
/// Test fixtures: example_packages/lib/sqflite/*
void main() {
  group('Sqflite Rules - Rule Instantiation', () {
    test('AvoidSqfliteTypeMismatchRule', () {
      final rule = AvoidSqfliteTypeMismatchRule();
      expect(rule.code.lowerCaseName, 'avoid_sqflite_type_mismatch');
      expect(
        rule.code.problemMessage,
        contains('[avoid_sqflite_type_mismatch]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('PreferSqfliteEncryptionRule', () {
      final rule = PreferSqfliteEncryptionRule();
      expect(rule.code.lowerCaseName, 'prefer_sqflite_encryption');
      expect(rule.code.problemMessage, contains('[prefer_sqflite_encryption]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('Sqflite Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/sqflite');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/sqflite/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });
}
