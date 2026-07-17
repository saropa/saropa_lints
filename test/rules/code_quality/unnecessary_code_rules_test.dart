import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/code_quality/unnecessary_code_rules.dart';

/// Tests for 15 Unnecessary Code lint rules.
///
/// Test fixtures: example/lib/unnecessary_code/*
void main() {
  group('Unnecessary Code Rules - Rule Instantiation', () {
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
      'AvoidEmptySpreadRule',
      'avoid_empty_spread',
      () => AvoidEmptySpreadRule(),
    );

    testRule(
      'AvoidUnnecessaryBlockRule',
      'avoid_unnecessary_block',
      () => AvoidUnnecessaryBlockRule(),
    );

    testRule(
      'AvoidUnnecessaryCallRule',
      'avoid_unnecessary_call',
      () => AvoidUnnecessaryCallRule(),
    );

    testRule(
      'AvoidUnnecessaryConstructorRule',
      'avoid_unnecessary_constructor',
      () => AvoidUnnecessaryConstructorRule(),
    );

    testRule(
      'AvoidUnnecessaryEnumArgumentsRule',
      'avoid_unnecessary_enum_arguments',
      () => AvoidUnnecessaryEnumArgumentsRule(),
    );

    testRule(
      'AvoidUnnecessaryEnumPrefixRule',
      'avoid_unnecessary_enum_prefix',
      () => AvoidUnnecessaryEnumPrefixRule(),
    );

    testRule(
      'AvoidUnnecessaryExtendsRule',
      'avoid_unnecessary_extends',
      () => AvoidUnnecessaryExtendsRule(),
    );

    testRule(
      'AvoidUnnecessaryGetterRule',
      'avoid_unnecessary_getter',
      () => AvoidUnnecessaryGetterRule(),
    );

    testRule(
      'AvoidUnnecessaryLengthCheckRule',
      'avoid_unnecessary_length_check',
      () => AvoidUnnecessaryLengthCheckRule(),
    );

    testRule(
      'AvoidUnnecessaryNegationsRule',
      'avoid_unnecessary_negations',
      () => AvoidUnnecessaryNegationsRule(),
    );

    testRule(
      'AvoidUnnecessaryNullAwareElementsRule',
      'avoid_unnecessary_null_aware_elements',
      () => AvoidUnnecessaryNullAwareElementsRule(),
    );

    testRule(
      'AvoidUnnecessarySuperRule',
      'avoid_unnecessary_super',
      () => AvoidUnnecessarySuperRule(),
    );

    testRule('NoEmptyBlockRule', 'no_empty_block', () => NoEmptyBlockRule());
    testRule('NoEmptyStringRule', 'no_empty_string', () => NoEmptyStringRule());
    testRule(
      'PreferReusingAssignedLocalRule',
      'prefer_reusing_assigned_local',
      () => PreferReusingAssignedLocalRule(),
    );
  });

  group('Unnecessary Code Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/unnecessary_code');

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
          'example/lib/unnecessary_code/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Unnecessary Code - Avoidance Rules', () {
    group('avoid_unnecessary_getter', () {
      test('rule offers quick fix (remove unnecessary getter)', () {
        final rule = AvoidUnnecessaryGetterRule();
        expect(rule.fixGenerators, isNotEmpty);
      });
    });
  });

  group('Unnecessary Code - General Rules', () {
    group('no_empty_block', () {
      test('rule offers quick fix (add no-op comment)', () {
        final rule = NoEmptyBlockRule();
        expect(rule.fixGenerators, isNotEmpty);
      });
    });

    group('prefer_reusing_assigned_local', () {
      test('rule offers quick fix (reuse the existing local)', () {
        final rule = PreferReusingAssignedLocalRule();
        expect(rule.fixGenerators, isNotEmpty);
      });
    });
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata,
  // fixture verification, and fix-generator checks while migrating to
  // analyzer-backed behavior tests.
}
