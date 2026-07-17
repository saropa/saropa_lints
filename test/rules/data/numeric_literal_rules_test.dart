import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/data/numeric_literal_rules.dart';

/// Tests for 11 Numeric Literal lint rules.
///
/// Test fixtures: example/lib/numeric_literal/*
void main() {
  group('Numeric Literal Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.lowerCaseName, codeName);
        expect(rule.code.problemMessage, contains('[$codeName]'));
        expect(rule.code.problemMessage.length, greaterThan(50));
        expect(rule.code.correctionMessage, isNotNull);
      });
    }

    testRule(
      'AvoidInconsistentDigitSeparatorsRule',
      'avoid_inconsistent_digit_separators',
      () => AvoidInconsistentDigitSeparatorsRule(),
    );

    testRule(
      'AvoidUnnecessaryDigitSeparatorsRule',
      'avoid_unnecessary_digit_separators',
      () => AvoidUnnecessaryDigitSeparatorsRule(),
    );

    testRule(
      'DoubleLiteralFormatRule',
      'double_literal_format',
      () => DoubleLiteralFormatRule(),
    );

    testRule('NoMagicNumberRule', 'no_magic_number', () => NoMagicNumberRule());

    testRule('NoMagicStringRule', 'no_magic_string', () => NoMagicStringRule());

    testRule(
      'PreferAdditionSubtractionAssignmentsRule',
      'prefer_addition_subtraction_assignments',
      () => PreferAdditionSubtractionAssignmentsRule(),
    );

    testRule(
      'PreferCompoundAssignmentOperatorsRule',
      'prefer_compound_assignment_operators',
      () => PreferCompoundAssignmentOperatorsRule(),
    );

    testRule(
      'PreferDigitSeparatorsRule',
      'prefer_digit_separators',
      () => PreferDigitSeparatorsRule(),
    );

    testRule(
      'AvoidDigitSeparatorsRule',
      'avoid_digit_separators',
      () => AvoidDigitSeparatorsRule(),
    );

    testRule(
      'NoMagicNumberInTestsRule',
      'no_magic_number_in_tests',
      () => NoMagicNumberInTestsRule(),
    );

    testRule(
      'NoMagicStringInTestsRule',
      'no_magic_string_in_tests',
      () => NoMagicStringInTestsRule(),
    );
  });

  group('Numeric Literal Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/numeric_literal');

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
      test('$fixture fixture exists', () {
        final file = File(
          'example/lib/numeric_literal/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture verification while migrating to analyzer-backed behavior tests.
}
