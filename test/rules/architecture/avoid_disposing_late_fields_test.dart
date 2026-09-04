import 'dart:io';

import 'package:saropa_lints/src/rules/architecture/avoid_disposing_late_fields_rules.dart';
import 'package:test/test.dart';

/// Tests for the `avoid_disposing_late_fields` lint rule.
///
/// Test fixture: example/lib/architecture/avoid_disposing_late_fields_fixture.dart
void main() {
  group('AvoidDisposingLateFieldsRule - Rule Instantiation', () {
    test('AvoidDisposingLateFieldsRule', () {
      final rule = AvoidDisposingLateFieldsRule();
      expect(rule.code.lowerCaseName, 'avoid_disposing_late_fields');
      expect(
        rule.code.problemMessage,
        contains('[avoid_disposing_late_fields]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('avoid_disposing_late_fields - Fixture Verification', () {
    const path =
        'example/lib/architecture/avoid_disposing_late_fields_fixture.dart';

    test('fixture exists', () {
      expect(File(path).existsSync(), isTrue, reason: 'Fixture must exist');
    });

    test('fixture has exactly two BAD (expect_lint) cases', () {
      final content = File(path).readAsStringSync();
      final count = RegExp(
        r'// expect_lint: avoid_disposing_late_fields',
      ).allMatches(content).length;
      expect(
        count,
        2,
        reason:
            'Two BAD dispose() calls on conditionally-initialized late '
            'fields should declare expect_lint (plain and null-aware call)',
      );
    });

    test(
      'fixture GOOD cases cover unconditional init, full branch coverage, '
      'guarded dispose, lazy init, and nullable field near-misses',
      () {
        final content = File(path).readAsStringSync();
        expect(content.contains('_good1_VideoPlayerWidgetState'), isTrue);
        expect(content.contains('_good2_ThemedControllerState'), isTrue);
        expect(content.contains('_good3_GuardedDisposeState'), isTrue);
        expect(content.contains('_good4_LazyControllerState'), isTrue);
        expect(content.contains('_good5_NullableControllerState'), isTrue);
      },
    );
  });
}
