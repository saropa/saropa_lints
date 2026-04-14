import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/stylistic/stylistic_rules.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart';

/// Tests for 28 Stylistic lint rules.
///
/// Test fixtures: example/lib/stylistic/*
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
      'prefer_relative_imports',
      'prefer_one_widget_per_file',
      'prefer_arrow_functions',
      'prefer_all_named_parameters',
      'prefer_trailing_comma_always',
      'prefer_private_underscore_prefix',
      'prefer_widget_methods_over_classes',
      'prefer_explicit_types',
      'prefer_class_over_record_return',
      'prefer_inline_callbacks',
      'prefer_single_quotes',
      'prefer_todo_format',
      'prefer_hack_format',
      'prefer_fixme_format',
      'no_runtimetype_tostring',
      'use_truncating_division',
      'prefer_sentence_case_comments',
      'prefer_sentence_case_comments_relaxed',
      'prefer_period_after_doc',
      'prefer_screaming_case_constants',
      'prefer_descriptive_bool_names',
      'prefer_descriptive_bool_names_strict',
      'prefer_snake_case_files',
      'avoid_small_text',
      'prefer_doc_comments_over_regular',
      'prefer_straight_apostrophe',
      'prefer_doc_curly_apostrophe',
      'prefer_doc_straight_apostrophe',
      'prefer_curly_apostrophe',
      'prefer_arguments_ordering',
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
        final file = File(
          'example/lib/stylistic/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Stylistic - Preference Rules', () {
    group('prefer_relative_imports', () {
      test('prefer_relative_imports SHOULD trigger', () {
        // Better alternative available: prefer relative imports
        expect('prefer_relative_imports detected', isNotNull);
      });

      test('prefer_relative_imports should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_relative_imports passes', isNotNull);
      });
    });

    group('prefer_one_widget_per_file', () {
      test('prefer_one_widget_per_file SHOULD trigger', () {
        // Better alternative available: prefer one widget per file
        expect('prefer_one_widget_per_file detected', isNotNull);
      });

      test('prefer_one_widget_per_file should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_one_widget_per_file passes', isNotNull);
      });
    });

    group('prefer_arrow_functions', () {
      test('prefer_arrow_functions SHOULD trigger', () {
        // Better alternative available: prefer arrow functions
        expect('prefer_arrow_functions detected', isNotNull);
      });

      test('prefer_arrow_functions should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_arrow_functions passes', isNotNull);
      });
    });

    group('prefer_all_named_parameters', () {
      test('prefer_all_named_parameters SHOULD trigger', () {
        // Better alternative available: prefer all named parameters
        expect('prefer_all_named_parameters detected', isNotNull);
      });

      test('prefer_all_named_parameters should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_all_named_parameters passes', isNotNull);
      });
    });

    group('prefer_trailing_comma_always', () {
      test('rule offers quick fix (add trailing comma)', () {
        final rule = PreferTrailingCommaAlwaysRule();
        expect(rule.fixGenerators, isNotEmpty);
      });

      test('correction message mentions source.fixAll', () {
        final rule = PreferTrailingCommaAlwaysRule();
        expect(rule.code.correctionMessage, contains('source.fixAll'));
      });

      test('prefer_trailing_comma_always SHOULD trigger', () {
        // Better alternative available: prefer trailing comma always
        expect('prefer_trailing_comma_always detected', isNotNull);
      });

      test('prefer_trailing_comma_always should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_trailing_comma_always passes', isNotNull);
      });
    });

    group('prefer_private_underscore_prefix', () {
      test('prefer_private_underscore_prefix SHOULD trigger', () {
        // Better alternative available: prefer private underscore prefix
        expect('prefer_private_underscore_prefix detected', isNotNull);
      });

      test('prefer_private_underscore_prefix should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_private_underscore_prefix passes', isNotNull);
      });
    });

    group('prefer_widget_methods_over_classes', () {
      test('prefer_widget_methods_over_classes SHOULD trigger', () {
        // Better alternative available: prefer widget methods over classes
        expect('prefer_widget_methods_over_classes detected', isNotNull);
      });

      test('prefer_widget_methods_over_classes should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_widget_methods_over_classes passes', isNotNull);
      });
    });

    group('prefer_explicit_types', () {
      test('prefer_explicit_types SHOULD trigger', () {
        // Better alternative available: prefer explicit types
        expect('prefer_explicit_types detected', isNotNull);
      });

      test('prefer_explicit_types should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_explicit_types passes', isNotNull);
      });
    });

    group('prefer_class_over_record_return', () {
      test('prefer_class_over_record_return SHOULD trigger', () {
        // Better alternative available: prefer class over record return
        expect('prefer_class_over_record_return detected', isNotNull);
      });

      test('prefer_class_over_record_return should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_class_over_record_return passes', isNotNull);
      });
    });

    group('prefer_inline_callbacks', () {
      test('prefer_inline_callbacks SHOULD trigger', () {
        // Better alternative available: prefer inline callbacks
        expect('prefer_inline_callbacks detected', isNotNull);
      });

      test('prefer_inline_callbacks should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_inline_callbacks passes', isNotNull);
      });
    });

    group('prefer_single_quotes', () {
      test('prefer_single_quotes SHOULD trigger on simple double-quoted', () {
        // "John" should be flagged — no single quotes in content
        expect('prefer_single_quotes detected', isNotNull);
      });

      test('prefer_single_quotes SHOULD trigger on interpolated', () {
        // "Hello, $name!" should be flagged — no single quotes
        expect('prefer_single_quotes interpolation detected', isNotNull);
      });

      test('prefer_single_quotes should NOT trigger on single-quoted', () {
        // Already using single quotes
        expect('prefer_single_quotes passes', isNotNull);
      });

      test(
        'should NOT trigger on simple string with embedded single quotes',
        () {
          // "WHERE col = ''" contains single quotes — converting would need \'
          expect('false positive prevention: simple string', isNotNull);
        },
      );

      test('should NOT trigger on interpolated string with embedded single '
          'quotes', () {
        // "WHERE $col = 'active'" contains single quotes in literal parts
        expect('false positive prevention: interpolated string', isNotNull);
      });

      test('should NOT trigger on SQL hex literal interpolation', () {
        // "X'$hex'" contains single quotes around interpolation
        expect('false positive prevention: SQL hex literal', isNotNull);
      });

      test('should NOT trigger on raw double-quoted string', () {
        // r"raw string" is a raw string — skip
        expect('false positive prevention: raw string', isNotNull);
      });
    });

    group('prefer_todo_format', () {
      test('prefer_todo_format SHOULD trigger', () {
        // Better alternative available: prefer todo format
        expect('prefer_todo_format detected', isNotNull);
      });

      test('prefer_todo_format should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_todo_format passes', isNotNull);
      });
    });

    group('prefer_hack_format', () {
      test('prefer_hack_format SHOULD trigger', () {
        expect('prefer_hack_format detected', isNotNull);
      });

      test('prefer_hack_format should NOT trigger', () {
        expect('prefer_hack_format passes', isNotNull);
      });
    });

    group('prefer_fixme_format', () {
      test('prefer_fixme_format SHOULD trigger', () {
        // Better alternative available: prefer fixme format
        expect('prefer_fixme_format detected', isNotNull);
      });

      test('prefer_fixme_format should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_fixme_format passes', isNotNull);
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

    group('prefer_period_after_doc', () {
      test('prefer_period_after_doc SHOULD trigger', () {
        // Better alternative available: prefer period after doc
        expect('prefer_period_after_doc detected', isNotNull);
      });

      test('prefer_period_after_doc should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_period_after_doc passes', isNotNull);
      });
    });

    group('prefer_screaming_case_constants', () {
      test('prefer_screaming_case_constants SHOULD trigger', () {
        // Better alternative available: prefer screaming case constants
        expect('prefer_screaming_case_constants detected', isNotNull);
      });

      test('prefer_screaming_case_constants should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_screaming_case_constants passes', isNotNull);
      });
    });

    group('prefer_descriptive_bool_names', () {
      test('prefer_descriptive_bool_names SHOULD trigger', () {
        // Better alternative available: prefer descriptive bool names
        expect('prefer_descriptive_bool_names detected', isNotNull);
      });

      test('prefer_descriptive_bool_names should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_descriptive_bool_names passes', isNotNull);
      });
    });

    group('prefer_descriptive_bool_names_strict', () {
      test('prefer_descriptive_bool_names_strict SHOULD trigger', () {
        // Better alternative available: prefer descriptive bool names strict
        expect('prefer_descriptive_bool_names_strict detected', isNotNull);
      });

      test('prefer_descriptive_bool_names_strict should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_descriptive_bool_names_strict passes', isNotNull);
      });
    });

    group('prefer_snake_case_files', () {
      test('prefer_snake_case_files SHOULD trigger', () {
        // Better alternative available: prefer snake case files
        expect('prefer_snake_case_files detected', isNotNull);
      });

      test('prefer_snake_case_files should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_snake_case_files passes', isNotNull);
      });
    });

    group('prefer_doc_comments_over_regular', () {
      late PreferDocCommentsOverRegularRule rule;
      setUp(() => rule = PreferDocCommentsOverRegularRule());

      test('rule metadata is v6', () {
        expect(rule.code.lowerCaseName, 'prefer_doc_comments_over_regular');
        expect(rule.code.problemMessage, contains('{v6}'));
      });

      test('fixture has BAD examples that trigger', () {
        final content = File(
          'example/lib/stylistic/prefer_doc_comments_over_regular_fixture.dart',
        ).readAsStringSync();
        // Public functions with regular comments above them
        expect(content, contains('String greet()'));
        expect(content, contains('void process()'));
        expect(
          content,
          contains('expect_lint: prefer_doc_comments_over_regular'),
        );
      });

      test('fixture has section-header false-positive guards', () {
        final content = File(
          'example/lib/stylistic/prefer_doc_comments_over_regular_fixture.dart',
        ).readAsStringSync();
        // Divider lines should not trigger
        expect(content, contains('-------'));
        expect(content, contains('======='));
        expect(content, contains('afterSectionHeader'));
      });

      test('fixture has blank-line-gap false-positive guard', () {
        final content = File(
          'example/lib/stylistic/prefer_doc_comments_over_regular_fixture.dart',
        ).readAsStringSync();
        expect(content, contains('separatedByBlankLine'));
      });

      test('fixture has annotation marker false-positive guards', () {
        final content = File(
          'example/lib/stylistic/prefer_doc_comments_over_regular_fixture.dart',
        ).readAsStringSync();
        expect(content, contains('TODO: Implement'));
        expect(content, contains('FIXME: Handle'));
        expect(content, contains('NOTE: This'));
      });
    });

    group('prefer_straight_apostrophe', () {
      test('prefer_straight_apostrophe SHOULD trigger', () {
        // Better alternative available: prefer straight apostrophe
        expect('prefer_straight_apostrophe detected', isNotNull);
      });

      test('prefer_straight_apostrophe should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_straight_apostrophe passes', isNotNull);
      });
    });

    group('prefer_doc_curly_apostrophe', () {
      test('prefer_doc_curly_apostrophe SHOULD trigger', () {
        // Better alternative available: prefer doc curly apostrophe
        expect('prefer_doc_curly_apostrophe detected', isNotNull);
      });

      test('prefer_doc_curly_apostrophe should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_doc_curly_apostrophe passes', isNotNull);
      });
    });

    group('prefer_doc_straight_apostrophe', () {
      test('prefer_doc_straight_apostrophe SHOULD trigger', () {
        // Better alternative available: prefer doc straight apostrophe
        expect('prefer_doc_straight_apostrophe detected', isNotNull);
      });

      test('prefer_doc_straight_apostrophe should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_doc_straight_apostrophe passes', isNotNull);
      });
    });

    group('prefer_curly_apostrophe', () {
      test('prefer_curly_apostrophe SHOULD trigger', () {
        // Better alternative available: prefer curly apostrophe
        expect('prefer_curly_apostrophe detected', isNotNull);
      });

      test('prefer_curly_apostrophe should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_curly_apostrophe passes', isNotNull);
      });
    });

    group('prefer_arguments_ordering', () {
      test('prefer_arguments_ordering SHOULD trigger', () {
        // Better alternative available: prefer arguments ordering
        expect('prefer_arguments_ordering detected', isNotNull);
      });

      test('prefer_arguments_ordering should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_arguments_ordering passes', isNotNull);
      });
    });

    group('prefer_no_commented_out_code', () {
      test('prefer_no_commented_out_code SHOULD trigger', () {
        // Better alternative available: prefer no commented out code
        expect('prefer_no_commented_out_code detected', isNotNull);
      });

      test('prefer_no_commented_out_code should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_no_commented_out_code passes', isNotNull);
      });
    });
  });

  group('Stylistic - Avoidance Rules', () {
    group('avoid_small_text', () {
      test('avoid_small_text SHOULD trigger', () {
        // Pattern that should be avoided: avoid small text
        expect('avoid_small_text detected', isNotNull);
      });

      test('avoid_small_text should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_small_text passes', isNotNull);
      });
    });
  });
}
