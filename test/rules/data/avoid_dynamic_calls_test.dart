import 'dart:io';

import 'package:saropa_lints/src/rules/data/avoid_dynamic_calls_rules.dart';
import 'package:test/test.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for the `avoid_dynamic_calls` lint rule.
///
/// Test fixture: example/lib/type_safety/avoid_dynamic_calls_fixture.dart
void main() {
  group('AvoidDynamicCallsRule - Rule Instantiation', () {
    test('AvoidDynamicCallsRule', () {
      final rule = AvoidDynamicCallsRule();
      expect(rule.code.lowerCaseName, 'avoid_dynamic_calls');
      expect(rule.code.problemMessage, contains('[avoid_dynamic_calls]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('AvoidDynamicCallsRule - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/type_safety');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);
      expect(fixtures, isNotEmpty);
    });

    test('avoid_dynamic_calls fixture exists', () {
      final file = File(
        'example/lib/type_safety/avoid_dynamic_calls_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });
  });
}
