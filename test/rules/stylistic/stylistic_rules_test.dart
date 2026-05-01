import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/stylistic/stylistic_rules.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart';

/// Tests for 28 Stylistic lint rules.
///
/// Test fixtures: example/lib/stylistic/*
// Large suite: instantiation + message checks; fixtures under example/lib/stylistic.
void main() {
  group('Stylistic Rules - Rule Instantiation', () {
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
      'PreferRelativeImportsRule',
      'prefer_relative_imports',
      () => PreferRelativeImportsRule(),
    );

    testRule(
      'PreferOneWidgetPerFileRule',
      'prefer_one_widget_per_file',
      () => PreferOneWidgetPerFileRule(),
    );

    testRule(
      'PreferArrowFunctionsRule',
      'prefer_arrow_functions',
      () => PreferArrowFunctionsRule(),
    );
    testRule(
      'PreferExpressionBodyGettersRule',
      'prefer_expression_body_getters',
      () => PreferExpressionBodyGettersRule(),
    );
    testRule(
      'AvoidTypesOnClosureParametersRule',
      'avoid_types_on_closure_parameters',
      () => AvoidTypesOnClosureParametersRule(),
    );
    testRule(
      'AvoidExplicitTypeDeclarationRule',
      'avoid_explicit_type_declaration',
      () => AvoidExplicitTypeDeclarationRule(),
    );
    testRule(
      'PreferExplicitNullChecksRule',
      'prefer_explicit_null_checks',
      () => PreferExplicitNullChecksRule(),
    );
    testRule(
      'PreferOptionalNamedParamsRule',
      'prefer_optional_named_params',
      () => PreferOptionalNamedParamsRule(),
    );
    testRule(
      'PreferOptionalPositionalParamsRule',
      'prefer_optional_positional_params',
      () => PreferOptionalPositionalParamsRule(),
    );
    testRule(
      'PreferPositionalBoolParamsRule',
      'prefer_positional_bool_params',
      () => PreferPositionalBoolParamsRule(),
    );
    testRule(
      'PreferBlockBodySettersRule',
      'prefer_block_body_setters',
      () => PreferBlockBodySettersRule(),
    );

    testRule(
      'PreferAllNamedParametersRule',
      'prefer_all_named_parameters',
      () => PreferAllNamedParametersRule(),
    );

    testRule(
      'PreferTrailingCommaAlwaysRule',
      'prefer_trailing_comma_always',
      () => PreferTrailingCommaAlwaysRule(),
    );

    testRule(
      'PreferPrivateUnderscorePrefixRule',
      'prefer_private_underscore_prefix',
      () => PreferPrivateUnderscorePrefixRule(),
    );

    testRule(
      'PreferWidgetMethodsOverClassesRule',
      'prefer_widget_methods_over_classes',
      () => PreferWidgetMethodsOverClassesRule(),
    );

    testRule(
      'PreferExplicitTypesRule',
      'prefer_explicit_types',
      () => PreferExplicitTypesRule(),
    );

    testRule(
      'PreferClassOverRecordReturnRule',
      'prefer_class_over_record_return',
      () => PreferClassOverRecordReturnRule(),
    );

    testRule(
      'PreferInlineCallbacksRule',
      'prefer_inline_callbacks',
      () => PreferInlineCallbacksRule(),
    );

    testRule(
      'PreferSingleQuotesRule',
      'prefer_single_quotes',
      () => PreferSingleQuotesRule(),
    );

    testRule(
      'PreferTodoFormatRule',
      'prefer_todo_format',
      () => PreferTodoFormatRule(),
    );

    testRule(
      'PreferHackFormatRule',
      'prefer_hack_format',
      () => PreferHackFormatRule(),
    );

    testRule(
      'PreferFixmeFormatRule',
      'prefer_fixme_format',
      () => PreferFixmeFormatRule(),
    );
    testRule(
      'NoRuntimeTypeToStringRule',
      'no_runtimetype_tostring',
      () => NoRuntimeTypeToStringRule(),
    );
    testRule(
      'UseTruncatingDivisionRule',
      'use_truncating_division',
      () => UseTruncatingDivisionRule(),
    );

    testRule(
      'PreferSentenceCaseCommentsRule',
      'prefer_sentence_case_comments',
      () => PreferSentenceCaseCommentsRule(),
    );

    testRule(
      'PreferSentenceCaseCommentsRelaxedRule',
      'prefer_sentence_case_comments_relaxed',
      () => PreferSentenceCaseCommentsRelaxedRule(),
    );

    testRule(
      'PreferPeriodAfterDocRule',
      'prefer_period_after_doc',
      () => PreferPeriodAfterDocRule(),
    );

    testRule(
      'PreferScreamingCaseConstantsRule',
      'prefer_screaming_case_constants',
      () => PreferScreamingCaseConstantsRule(),
    );

    testRule(
      'PreferDescriptiveBoolNamesRule',
      'prefer_descriptive_bool_names',
      () => PreferDescriptiveBoolNamesRule(),
    );

    testRule(
      'PreferDescriptiveBoolNamesStrictRule',
      'prefer_descriptive_bool_names_strict',
      () => PreferDescriptiveBoolNamesStrictRule(),
    );

    testRule(
      'PreferSnakeCaseFilesRule',
      'prefer_snake_case_files',
      () => PreferSnakeCaseFilesRule(),
    );

    testRule(
      'AvoidSmallTextRule',
      'avoid_small_text',
      () => AvoidSmallTextRule(),
    );

    testRule(
      'PreferDocCommentsOverRegularRule',
      'prefer_doc_comments_over_regular',
      () => PreferDocCommentsOverRegularRule(),
    );

    testRule(
      'PreferStraightApostropheRule',
      'prefer_straight_apostrophe',
      () => PreferStraightApostropheRule(),
    );

    testRule(
      'PreferDocCurlyApostropheRule',
      'prefer_doc_curly_apostrophe',
      () => PreferDocCurlyApostropheRule(),
    );

    testRule(
      'PreferDocStraightApostropheRule',
      'prefer_doc_straight_apostrophe',
      () => PreferDocStraightApostropheRule(),
    );

    testRule(
      'PreferCurlyApostropheRule',
      'prefer_curly_apostrophe',
      () => PreferCurlyApostropheRule(),
    );

    testRule(
      'ArgumentsOrderingRule',
      'prefer_arguments_ordering',
      () => ArgumentsOrderingRule(),
    );

    testRule(
      'AvoidCommentedOutCodeRule',
      'prefer_no_commented_out_code',
      () => AvoidCommentedOutCodeRule(),
    );

    testRule(
      'AvoidEscapingInnerQuotesRule',
      'avoid_escaping_inner_quotes',
      () => AvoidEscapingInnerQuotesRule(),
    );

    testRule(
      'AvoidSingleCascadeInExpressionStatementsRule',
      'avoid_single_cascade_in_expression_statements',
      () => AvoidSingleCascadeInExpressionStatementsRule(),
    );

    testRule(
      'PreferAdjacentStringsRule',
      'prefer_adjacent_strings',
      () => PreferAdjacentStringsRule(),
    );

    testRule(
      'PreferInterpolationToComposeRule',
      'prefer_interpolation_to_compose',
      () => PreferInterpolationToComposeRule(),
    );

    testRule(
      'PreferRawStringsRule',
      'prefer_raw_strings',
      () => PreferRawStringsRule(),
    );
  });

  group('Stylistic Rules - Fixture Verification', () {
    final fixtures = [
      'prefer_trailing_comma_always',
      'prefer_widget_methods_over_classes',
      'prefer_class_over_record_return',
      'prefer_single_quotes',
      'prefer_todo_format',
      'prefer_hack_format',
      'prefer_fixme_format',
      'no_runtimetype_tostring',
      'use_truncating_division',
      'prefer_period_after_doc',
      'prefer_descriptive_bool_names',
      'prefer_descriptive_bool_names_strict',
      'prefer_doc_comments_over_regular',
      'prefer_straight_apostrophe',
      'prefer_doc_curly_apostrophe',
      'prefer_doc_straight_apostrophe',
      'prefer_curly_apostrophe',
      'prefer_no_commented_out_code',
      'avoid_escaping_inner_quotes',
      'avoid_single_cascade_in_expression_statements',
      'avoid_types_on_closure_parameters',
      'avoid_explicit_type_declaration',
      'prefer_explicit_null_checks',
      'prefer_adjacent_strings',
      'prefer_block_body_setters',
      'prefer_expression_body_getters',
      'prefer_interpolation_to_compose',
      'prefer_raw_strings',
      'prefer_optional_named_params',
      'prefer_optional_positional_params',
      'prefer_positional_bool_params',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/stylistic/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Stylistic - Preference Rules', () {
    group('prefer_trailing_comma_always', () {
      test('rule offers quick fix (add trailing comma)', () {
        final rule = PreferTrailingCommaAlwaysRule();
        expect(rule.fixGenerators, isNotEmpty);
      });

      test('correction message mentions source.fixAll', () {
        final rule = PreferTrailingCommaAlwaysRule();
        expect(rule.code.correctionMessage, contains('source.fixAll'));
      });
    });

    group('prefer_single_quotes', () {
      test('has conflictingRules metadata', () {
        final rule = PreferSingleQuotesRule();
        expect(rule.conflictingRules, contains('prefer_double_quotes'));
      });
    });

    group('prefer_sentence_case_comments', () {
      late PreferSentenceCaseCommentsRule rule;
      setUp(() => rule = PreferSentenceCaseCommentsRule());

      test('threshold is 2 words', () {
        expect(rule.maxShortCommentWords, 2);
      });

      test('rule name matches expected', () {
        expect(rule.code.lowerCaseName, 'prefer_sentence_case_comments');
      });

      test('has capitalize quick fix', () {
        expect(rule.fixGenerators, isNotEmpty);
      });

      test('impact is opinionated', () {
        expect(rule.impact, LintImpact.opinionated);
      });

      test('does not conflict with relaxed variant name', () {
        final relaxed = PreferSentenceCaseCommentsRelaxedRule();
        expect(rule.code.lowerCaseName, isNot(relaxed.code.lowerCaseName));
      });
    });

    group('prefer_sentence_case_comments_relaxed', () {
      late PreferSentenceCaseCommentsRelaxedRule rule;
      setUp(() => rule = PreferSentenceCaseCommentsRelaxedRule());

      test('threshold is 4 words', () {
        expect(rule.maxShortCommentWords, 4);
      });

      test('rule name matches expected', () {
        expect(
          rule.code.lowerCaseName,
          'prefer_sentence_case_comments_relaxed',
        );
      });

      test('has capitalize quick fix', () {
        expect(rule.fixGenerators, isNotEmpty);
      });

      test('impact is opinionated', () {
        expect(rule.impact, LintImpact.opinionated);
      });

      test('higher threshold than strict variant', () {
        final strict = PreferSentenceCaseCommentsRule();
        expect(
          rule.maxShortCommentWords,
          greaterThan(strict.maxShortCommentWords),
        );
      });
    });

    group('prefer_doc_comments_over_regular', () {
      late PreferDocCommentsOverRegularRule rule;
      setUp(() => rule = PreferDocCommentsOverRegularRule());

      test('rule metadata is v6', () {
        expect(rule.code.lowerCaseName, 'prefer_doc_comments_over_regular');
        expect(rule.code.problemMessage, contains('{v6}'));
      });
    });

    group('prefer_straight_apostrophe', () {
      test('has conflictingRules metadata', () {
        final rule = PreferStraightApostropheRule();
        expect(rule.conflictingRules, contains('prefer_curly_apostrophe'));
      });
    });

    group('prefer_doc_curly_apostrophe', () {
      test('has conflictingRules metadata', () {
        final rule = PreferDocCurlyApostropheRule();
        expect(
          rule.conflictingRules,
          contains('prefer_doc_straight_apostrophe'),
        );
      });
    });

    group('prefer_doc_straight_apostrophe', () {
      test('has conflictingRules metadata', () {
        final rule = PreferDocStraightApostropheRule();
        expect(rule.conflictingRules, contains('prefer_doc_curly_apostrophe'));
      });
    });

    group('prefer_curly_apostrophe', () {
      test('has conflictingRules metadata', () {
        final rule = PreferCurlyApostropheRule();
        expect(rule.conflictingRules, contains('prefer_straight_apostrophe'));
      });
    });
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata,
  // fixture verification, and targeted metadata checks.
}
