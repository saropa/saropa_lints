import 'dart:io';

import 'package:saropa_lints/src/rules/flow/duplicate_value_rules.dart';
import 'package:test/test.dart';

/// Tests for the `duplicate_value` lint rule.
///
/// Test fixture: example/lib/control_flow/duplicate_value_fixture.dart
void main() {
  group('DuplicateValueRule - Rule Instantiation', () {
    test('DuplicateValueRule', () {
      final rule = DuplicateValueRule();
      expect(rule.code.lowerCaseName, 'duplicate_value');
      expect(rule.code.problemMessage, contains('[duplicate_value]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('DuplicateValueRule - Fixture Verification', () {
    test('fixture file exists', () {
      final file = File(
        'example/lib/control_flow/duplicate_value_fixture.dart',
      );

      expect(file.existsSync(), isTrue);
    });
  });
}
