import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/stylistic/stylistic_error_testing_rules.dart';

/// Tests for 13 Stylistic Error Testing lint rules.
///
/// Test fixtures: example/lib/stylistic_error_testing/*
void main() {
  group('Stylistic Error Testing Rules - Rule Instantiation', () {
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
      'PreferSpecificExceptionsRule',
      'prefer_specific_exceptions',
      () => PreferSpecificExceptionsRule(),
    );

    testRule(
      'PreferGenericExceptionRule',
      'prefer_generic_exception',
      () => PreferGenericExceptionRule(),
    );

    testRule(
      'PreferExceptionSuffixRule',
      'prefer_exception_suffix',
      () => PreferExceptionSuffixRule(),
    );

    testRule(
      'PreferErrorSuffixRule',
      'prefer_error_suffix',
      () => PreferErrorSuffixRule(),
    );

    testRule(
      'PreferOnOverCatchRule',
      'prefer_on_over_catch',
      () => PreferOnOverCatchRule(),
    );

    testRule(
      'PreferCatchOverOnRule',
      'prefer_catch_over_on',
      () => PreferCatchOverOnRule(),
    );

    testRule(
      'PreferGivenWhenThenCommentsRule',
      'prefer_given_when_then_comments',
      () => PreferGivenWhenThenCommentsRule(),
    );

    testRule(
      'PreferSelfDocumentingTestsRule',
      'prefer_self_documenting_tests',
      () => PreferSelfDocumentingTestsRule(),
    );

    testRule(
      'PreferExpectOverAssertInTestsRule',
      'prefer_expect_over_assert_in_tests',
      () => PreferExpectOverAssertInTestsRule(),
    );

    testRule(
      'PreferSingleExpectationPerTestRule',
      'prefer_single_expectation_per_test',
      () => PreferSingleExpectationPerTestRule(),
    );

    testRule(
      'PreferGroupedExpectationsRule',
      'prefer_grouped_expectations',
      () => PreferGroupedExpectationsRule(),
    );

    testRule(
      'PreferTestNameShouldWhenRule',
      'prefer_test_name_should_when',
      () => PreferTestNameShouldWhenRule(),
    );

    testRule(
      'PreferTestNameDescriptiveRule',
      'prefer_test_name_descriptive',
      () => PreferTestNameDescriptiveRule(),
    );
  });

  group('Stylistic Error Testing Rules - Fixture Verification', () {
    final fixtures = [
      'prefer_specific_exceptions',
      'prefer_exception_suffix',
      'prefer_error_suffix',
      'prefer_catch_over_on',
      'prefer_given_when_then_comments',
      'prefer_self_documenting_tests',
      'prefer_single_expectation_per_test',
      'prefer_grouped_expectations',
      'prefer_test_name_should_when',
      'prefer_test_name_descriptive',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example/lib/stylistic_error_testing/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture verification while migrating to analyzer-backed behavior tests.
}
