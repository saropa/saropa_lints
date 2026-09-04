import 'dart:io';

import 'package:saropa_lints/src/rules/codegen/specify_unknown_enum_value_rules.dart';
import 'package:test/test.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for the specify_unknown_enum_value lint rule.
///
/// Test fixtures: example/lib/codegen/specify_unknown_enum_value_fixture.dart
void main() {
  group('Specify Unknown Enum Value Rule - Rule Instantiation', () {
    test('SpecifyUnknownEnumValueRule', () {
      final rule = SpecifyUnknownEnumValueRule();
      expect(rule.code.lowerCaseName, 'specify_unknown_enum_value');
      expect(
        rule.code.problemMessage,
        contains('[specify_unknown_enum_value]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('Specify Unknown Enum Value Rule - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/codegen');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);
      expect(fixtures, isNotEmpty);
    });

    test('specify_unknown_enum_value fixture exists', () {
      final file = File(
        'example/lib/codegen/specify_unknown_enum_value_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });
  });
}
