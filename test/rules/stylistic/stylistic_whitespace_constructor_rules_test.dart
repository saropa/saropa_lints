import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/stylistic/stylistic_whitespace_constructor_rules.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for 15 Stylistic Whitespace Constructor lint rules.
///
/// Test fixtures: example/lib/stylistic_whitespace_constructor/*
void main() {
  group('Stylistic Whitespace Constructor Rules - Rule Instantiation', () {
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
      'PreferNoBlankLineBeforeReturnRule',
      'prefer_no_blank_line_before_return',
      () => PreferNoBlankLineBeforeReturnRule(),
    );

    testRule(
      'PreferBlankLineAfterDeclarationsRule',
      'prefer_blank_line_after_declarations',
      () => PreferBlankLineAfterDeclarationsRule(),
    );

    testRule(
      'PreferCompactDeclarationsRule',
      'prefer_compact_declarations',
      () => PreferCompactDeclarationsRule(),
    );

    testRule(
      'PreferBlankLinesBetweenMembersRule',
      'prefer_blank_lines_between_members',
      () => PreferBlankLinesBetweenMembersRule(),
    );

    testRule(
      'PreferCompactClassMembersRule',
      'prefer_compact_class_members',
      () => PreferCompactClassMembersRule(),
    );

    testRule(
      'PreferNoBlankLineInsideBlocksRule',
      'prefer_no_blank_line_inside_blocks',
      () => PreferNoBlankLineInsideBlocksRule(),
    );

    testRule(
      'PreferSingleBlankLineMaxRule',
      'prefer_single_blank_line_max',
      () => PreferSingleBlankLineMaxRule(),
    );

    testRule(
      'PreferSuperParametersRule',
      'prefer_super_parameters',
      () => PreferSuperParametersRule(),
    );

    testRule(
      'PreferInitializingFormalsRule',
      'prefer_initializing_formals',
      () => PreferInitializingFormalsRule(),
    );

    testRule(
      'PreferConstructorBodyAssignmentRule',
      'prefer_constructor_body_assignment',
      () => PreferConstructorBodyAssignmentRule(),
    );

    testRule(
      'PreferFactoryForValidationRule',
      'prefer_factory_for_validation',
      () => PreferFactoryForValidationRule(),
    );

    testRule(
      'PreferConstructorAssertionRule',
      'prefer_constructor_assertion',
      () => PreferConstructorAssertionRule(),
    );

    testRule(
      'PreferRequiredBeforeOptionalRule',
      'prefer_required_before_optional',
      () => PreferRequiredBeforeOptionalRule(),
    );

    testRule(
      'PreferGroupedByPurposeRule',
      'prefer_grouped_by_purpose',
      () => PreferGroupedByPurposeRule(),
    );

    testRule(
      'PreferRethrowOverThrowERule',
      'prefer_rethrow_over_throw_e',
      () => PreferRethrowOverThrowERule(),
    );
  });

  group('Stylistic Whitespace Constructor Rules - Fixture Verification', () {
    final fixtureDir = Directory(
      'example/lib/stylistic_whitespace_constructor',
    );
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example/lib/stylistic_whitespace_constructor/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture verification while migrating to analyzer-backed behavior tests.
}
