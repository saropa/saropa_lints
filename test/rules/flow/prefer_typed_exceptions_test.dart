import 'dart:io';

import 'package:saropa_lints/src/rules/flow/prefer_typed_exceptions_rules.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart' show TestRelevance;
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
      // Problem Message Requirement (CLAUDE.md): message must exceed 200
      // chars. Was previously asserted at >50, which would not catch a
      // future edit that shrank the message below the documented standard.
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
    });

    // Proposal Edge Case 3 required the test-file exemption to be verified
    // rather than assumed. The rule does not override `testRelevance`, so it
    // inherits SaropaLintRule's default TestRelevance.never (skip test
    // files) -- this pins that inheritance so a future override can't
    // silently change the behavior without a test failing.
    test('inherits TestRelevance.never (skips test files by default)', () {
      final rule = PreferTypedExceptionsRule();
      expect(rule.testRelevance, TestRelevance.never);
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
