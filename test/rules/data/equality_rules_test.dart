import 'dart:io';

import 'package:saropa_lints/src/rules/data/equality_rules.dart';
import 'package:test/test.dart';

/// Tests for 7 Equality lint rules.
///
/// Test fixtures: example/lib/equality/*
void main() {
  group('Equality Rules - Rule Instantiation', () {
    test('AvoidEqualExpressionsRule', () {
      final rule = AvoidEqualExpressionsRule();
      expect(rule.code.lowerCaseName, 'avoid_equal_expressions');
      expect(rule.code.problemMessage, contains('[avoid_equal_expressions]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidNegationsInEqualityChecksRule', () {
      final rule = AvoidNegationsInEqualityChecksRule();
      expect(rule.code.lowerCaseName, 'avoid_negations_in_equality_checks');
      expect(
        rule.code.problemMessage,
        contains('[avoid_negations_in_equality_checks]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidSelfAssignmentRule', () {
      final rule = AvoidSelfAssignmentRule();
      expect(rule.code.lowerCaseName, 'avoid_self_assignment');
      expect(rule.code.problemMessage, contains('[avoid_self_assignment]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidSelfCompareRule', () {
      final rule = AvoidSelfCompareRule();
      expect(rule.code.lowerCaseName, 'avoid_self_compare');
      expect(rule.code.problemMessage, contains('[avoid_self_compare]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidUnnecessaryCompareToRule', () {
      final rule = AvoidUnnecessaryCompareToRule();
      expect(rule.code.lowerCaseName, 'avoid_unnecessary_compare_to');
      expect(
        rule.code.problemMessage,
        contains('[avoid_unnecessary_compare_to]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('NoEqualArgumentsRule', () {
      final rule = NoEqualArgumentsRule();
      expect(rule.code.lowerCaseName, 'no_equal_arguments');
      expect(rule.code.problemMessage, contains('[no_equal_arguments]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidDatetimeComparisonWithoutPrecisionRule', () {
      final rule = AvoidDatetimeComparisonWithoutPrecisionRule();
      expect(
        rule.code.lowerCaseName,
        'avoid_datetime_comparison_without_precision',
      );
      expect(
        rule.code.problemMessage,
        contains('[avoid_datetime_comparison_without_precision]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('Equality Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/equality');

    // Auto-discover fixtures from disk so new files are verified

    // automatically — no manual list to maintain.

    final fixtures =
        fixtureDir
            .listSync()
            .whereType<File>()
            .map((f) => f.uri.pathSegments.last)
            .where((name) => name.endsWith('_fixture.dart'))
            .map((name) => name.replaceAll('_fixture.dart', ''))
            .toList()
          ..sort();

    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('\$fixture fixture exists', () {
        final file = File('example/lib/equality/${fixture}_fixture.dart');

        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Equality - Avoidance Rules', () {
    group('avoid_self_assignment', () {
      test('rule offers quick fix (remove self-assignment statement)', () {
        final rule = AvoidSelfAssignmentRule();
        expect(rule.fixGenerators, isNotEmpty);
      });
    });
  });
}
