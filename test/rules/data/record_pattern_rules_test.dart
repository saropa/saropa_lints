import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/data/record_pattern_rules.dart';

/// Tests for 19 Record Pattern lint rules.
///
/// Test fixtures: example/lib/record_pattern/*
void main() {
  group('Record Pattern Rules - Rule Instantiation', () {
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
      'AvoidBottomTypeInPatternsRule',
      'avoid_bottom_type_in_patterns',
      () => AvoidBottomTypeInPatternsRule(),
    );

    testRule(
      'AvoidBottomTypeInRecordsRule',
      'avoid_bottom_type_in_records',
      () => AvoidBottomTypeInRecordsRule(),
    );

    testRule(
      'AvoidExplicitPatternFieldNameRule',
      'avoid_explicit_pattern_field_name',
      () => AvoidExplicitPatternFieldNameRule(),
    );

    testRule(
      'AvoidExtensionsOnRecordsRule',
      'avoid_extensions_on_records',
      () => AvoidExtensionsOnRecordsRule(),
    );

    testRule(
      'AvoidFunctionTypeInRecordsRule',
      'avoid_function_type_in_records',
      () => AvoidFunctionTypeInRecordsRule(),
    );

    testRule(
      'AvoidKeywordsInWildcardPatternRule',
      'avoid_keywords_in_wildcard_pattern',
      () => AvoidKeywordsInWildcardPatternRule(),
    );

    testRule(
      'AvoidLongRecordsRule',
      'avoid_long_records',
      () => AvoidLongRecordsRule(),
    );

    testRule(
      'AvoidMixingNamedAndPositionalFieldsRule',
      'avoid_mixing_named_and_positional_fields',
      () => AvoidMixingNamedAndPositionalFieldsRule(),
    );

    testRule(
      'AvoidNestedRecordsRule',
      'avoid_nested_records',
      () => AvoidNestedRecordsRule(),
    );

    testRule(
      'AvoidOneFieldRecordsRule',
      'avoid_one_field_records',
      () => AvoidOneFieldRecordsRule(),
    );

    testRule(
      'AvoidPositionalRecordFieldAccessRule',
      'avoid_positional_record_field_access',
      () => AvoidPositionalRecordFieldAccessRule(),
    );

    testRule(
      'AvoidRedundantPositionalFieldNameRule',
      'avoid_redundant_positional_field_name',
      () => AvoidRedundantPositionalFieldNameRule(),
    );

    testRule(
      'AvoidSingleFieldDestructuringRule',
      'avoid_single_field_destructuring',
      () => AvoidSingleFieldDestructuringRule(),
    );

    testRule(
      'MoveRecordsToTypedefsRule',
      'move_records_to_typedefs',
      () => MoveRecordsToTypedefsRule(),
    );

    testRule(
      'PatternFieldsOrderingRule',
      'prefer_sorted_pattern_fields',
      () => PatternFieldsOrderingRule(),
    );

    testRule(
      'PreferSimplerPatternsNullCheckRule',
      'prefer_simpler_patterns_null_check',
      () => PreferSimplerPatternsNullCheckRule(),
    );

    testRule(
      'PreferWildcardPatternRule',
      'prefer_wildcard_pattern',
      () => PreferWildcardPatternRule(),
    );

    testRule(
      'RecordFieldsOrderingRule',
      'prefer_sorted_record_fields',
      () => RecordFieldsOrderingRule(),
    );

    testRule(
      'PreferPatternDestructuringRule',
      'prefer_pattern_destructuring',
      () => PreferPatternDestructuringRule(),
    );

    testRule(
      'PreferClassDestructuringRule',
      'prefer_class_destructuring',
      () => PreferClassDestructuringRule(),
    );
  });

  group('Record Pattern Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/record_pattern');

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
        final file = File('example/lib/record_pattern/${fixture}_fixture.dart');

        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture verification while migrating to analyzer-backed behavior tests.
}
