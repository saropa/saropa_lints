import 'dart:io';

import 'package:saropa_lints/src/rules/flow/prefer_typed_exceptions_rules.dart';
import 'package:test/test.dart';

/// Tests for the `prefer_typed_exceptions` lint rule.
///
/// Test fixture: example/lib/exception/prefer_typed_exceptions_fixture.dart
void main() {
  group('PreferTypedExceptionsRule - Rule Instantiation', () {
    test('PreferTypedExceptionsRule', () {
      final rule = PreferTypedExceptionsRule();
      expect(rule.code.lowerCaseName, 'prefer_typed_exceptions');
      expect(rule.code.problemMessage, contains('[prefer_typed_exceptions]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('PreferTypedExceptionsRule - Fixture Verification', () {
    test('fixture file exists', () {
      final file = File(
        'example/lib/exception/prefer_typed_exceptions_fixture.dart',
      );

      expect(file.existsSync(), isTrue);
    });
  });
}
