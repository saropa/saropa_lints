import 'dart:io';

import 'package:saropa_lints/src/rules/flow/duplicate_value_rules.dart';
import 'package:test/test.dart';

/// Tests for the `duplicate_value` lint rule.
///
/// Test fixture: example/lib/control_flow/duplicate_value_fixture.dart
///
/// The fixture's `parenthesizedDuplicate`/`parenthesizedDistinct` cases are
/// a regression check for a paren-flattening bug: `_collectOperands` must
/// unwrap `ParenthesizedExpression` before recursing so a same-operator
/// chain split across explicit grouping parens (`a || (b || a)`) is still
/// flattened and compared as one chain. Per project convention this suite
/// only pins rule instantiation/messages; actual firing is verified via
/// the scan CLI (see memory/reference_verify_rule_behavior_scan_cli.md).
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
