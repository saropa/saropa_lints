import 'dart:io';

import 'package:saropa_lints/src/rules/core/document_enum_rules.dart';
import 'package:test/test.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for the document_enum lint rule.
///
/// Test fixtures: example/lib/core/document_enum_fixture.dart
void main() {
  group('Document Enum Rule - Rule Instantiation', () {
    test('DocumentEnumRule', () {
      final rule = DocumentEnumRule();
      expect(rule.code.lowerCaseName, 'document_enum');
      expect(rule.code.problemMessage, contains('[document_enum]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('Document Enum Rule - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/core');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);
      expect(fixtures, isNotEmpty);
    });

    test('document_enum fixture exists', () {
      final file = File('example/lib/core/document_enum_fixture.dart');
      expect(file.existsSync(), isTrue);
    });
  });
}
