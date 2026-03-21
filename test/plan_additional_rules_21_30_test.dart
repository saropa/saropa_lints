import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

/// Registration, tier, and fixture checks for plan_additional_rules_21_through_30.
void main() {
  const ruleNames = <String>[
    'conflicting_constructor_and_static_member',
    'duplicate_constructor',
    'duplicate_field_name',
    'field_initializer_redirecting_constructor',
    'illegal_concrete_enum_member',
    'invalid_extension_argument_count',
    'invalid_field_name',
    'invalid_literal_annotation',
    'invalid_non_virtual_annotation',
    'invalid_super_formal_parameter_location',
  ];

  group('Plan 21–30 rules - registration', () {
    test('all rules are registered in allSaropaRules', () {
      final names = allSaropaRules
          .map((r) => r.code.name.toLowerCase())
          .toSet();
      for (final name in ruleNames) {
        expect(
          names.contains(name),
          isTrue,
          reason: 'Rule $name should be registered',
        );
      }
    });

    test('all rules are in essential tier', () {
      final essential = getRulesForTier('essential');
      for (final name in ruleNames) {
        expect(
          essential.contains(name),
          isTrue,
          reason: '$name should be in essential tier',
        );
      }
    });
  });

  group('Plan 21–30 rules - fixture', () {
    test('fixture file exists', () {
      final file = File('example/lib/plan_additional_rules_21_30_fixture.dart');
      expect(file.existsSync(), isTrue);
    });

    test('fixture has expect_lint for implemented BAD cases', () {
      final file = File('example/lib/plan_additional_rules_21_30_fixture.dart');
      final content = file.readAsStringSync();
      const withExpectLint = <String>[
        'duplicate_constructor',
        'conflicting_constructor_and_static_member',
        'duplicate_field_name',
        'field_initializer_redirecting_constructor',
        'invalid_super_formal_parameter_location',
        'illegal_concrete_enum_member',
        'invalid_extension_argument_count',
        'invalid_literal_annotation',
        'invalid_non_virtual_annotation',
      ];
      for (final name in withExpectLint) {
        expect(
          content.contains('expect_lint: $name'),
          isTrue,
          reason: 'Fixture should contain // expect_lint: $name',
        );
      }
      expect(
        content.contains('expect_lint: invalid_field_name'),
        isFalse,
        reason:
            'invalid_field_name: parser rejects keyword labels; no BAD line in fixture',
      );
    });

    test(
      'fixture has one expect_lint marker per BAD diagnostic site (11 total)',
      () {
        final file = File(
          'example/lib/plan_additional_rules_21_30_fixture.dart',
        );
        final content = file.readAsStringSync();
        final matches = RegExp(
          r'// expect_lint: \w+',
        ).allMatches(content).toList();
        expect(
          matches.length,
          equals(11),
          reason:
              'Two duplicate_constructor, two conflicting_constructor…, plus seven single-site rules',
        );
      },
    );

    test('GOOD section has no expect_lint markers (false-positive guard)', () {
      final file = File('example/lib/plan_additional_rules_21_30_fixture.dart');
      final lines = file.readAsStringSync().split('\n');
      final start = lines.indexWhere(
        (l) => l.contains('GOOD / false-positive guards'),
      );
      expect(start, greaterThan(-1));
      for (var i = start; i < lines.length; i++) {
        expect(
          lines[i].contains('expect_lint:'),
          isFalse,
          reason:
              'Line ${i + 1} in GOOD section must not assert a lint: ${lines[i]}',
        );
      }
    });
  });
}
