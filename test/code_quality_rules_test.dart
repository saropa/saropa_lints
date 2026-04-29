import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/code_quality/code_quality_avoid_rules.dart';
import 'package:saropa_lints/src/rules/code_quality/code_quality_control_flow_rules.dart';
import 'package:saropa_lints/src/rules/code_quality/code_quality_prefer_rules.dart';
import 'package:saropa_lints/src/rules/code_quality/code_quality_variables_rules.dart';

/// Tests for 101 code quality lint rules.
///
// See group names for sub-suites; example fixtures under example/lib/code_quality.
/// These rules cover type safety, null handling, dead code detection,
/// pattern matching, collection best practices, string handling,
/// switch expressions, and code maintainability.
///
/// Test fixtures: example/lib/code_quality/*
void main() {
  group('Code Quality Rules - Rule Instantiation', () {
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
      'AvoidAdjacentStringsRule',
      'avoid_adjacent_strings',
      () => AvoidAdjacentStringsRule(),
    );

    testRule(
      'AvoidEnumValuesByIndexRule',
      'avoid_enum_values_by_index',
      () => AvoidEnumValuesByIndexRule(),
    );

    testRule(
      'AvoidIncorrectUriRule',
      'avoid_incorrect_uri',
      () => AvoidIncorrectUriRule(),
    );

    testRule(
      'AvoidLateKeywordRule',
      'avoid_late_keyword',
      () => AvoidLateKeywordRule(),
    );

    testRule(
      'AvoidMissedCallsRule',
      'avoid_missed_calls',
      () => AvoidMissedCallsRule(),
    );

    testRule(
      'AvoidMisusedSetLiteralsRule',
      'avoid_misused_set_literals',
      () => AvoidMisusedSetLiteralsRule(),
    );

    testRule(
      'AvoidPassingSelfAsArgumentRule',
      'avoid_passing_self_as_argument',
      () => AvoidPassingSelfAsArgumentRule(),
    );

    testRule(
      'AvoidRecursiveCallsRule',
      'avoid_recursive_calls',
      () => AvoidRecursiveCallsRule(),
    );

    testRule(
      'AvoidRecursiveToStringRule',
      'avoid_recursive_tostring',
      () => AvoidRecursiveToStringRule(),
    );

    testRule(
      'AvoidReferencingDiscardedVariablesRule',
      'avoid_referencing_discarded_variables',
      () => AvoidReferencingDiscardedVariablesRule(),
    );

    testRule(
      'AvoidRedundantPragmaInlineRule',
      'avoid_redundant_pragma_inline',
      () => AvoidRedundantPragmaInlineRule(),
    );

    testRule(
      'AvoidSubstringRule',
      'avoid_string_substring',
      () => AvoidSubstringRule(),
    );

    testRule(
      'AvoidUnknownPragmaRule',
      'avoid_unknown_pragma',
      () => AvoidUnknownPragmaRule(),
    );

    testRule(
      'AvoidUnusedParametersRule',
      'avoid_unused_parameters',
      () => AvoidUnusedParametersRule(),
    );

    testRule(
      'AvoidWeakCryptographicAlgorithmsRule',
      'avoid_weak_cryptographic_algorithms',
      () => AvoidWeakCryptographicAlgorithmsRule(),
    );

    testRule(
      'MissingUseResultAnnotationRule',
      'missing_use_result_annotation',
      () => MissingUseResultAnnotationRule(),
    );

    testRule(
      'NoObjectDeclarationRule',
      'no_object_declaration',
      () => NoObjectDeclarationRule(),
    );

    testRule(
      'PreferBothInliningAnnotationsRule',
      'prefer_both_inlining_annotations',
      () => PreferBothInliningAnnotationsRule(),
    );

    testRule(
      'PreferDedicatedMediaQueryMethodRule',
      'prefer_dedicated_media_query_method',
      () => PreferDedicatedMediaQueryMethodRule(),
    );

    testRule(
      'PreferEnumsByNameRule',
      'prefer_enums_by_name',
      () => PreferEnumsByNameRule(),
    );

    testRule(
      'PreferExtractingFunctionCallbacksRule',
      'prefer_extracting_function_callbacks',
      () => PreferExtractingFunctionCallbacksRule(),
    );

    testRule(
      'PreferNullAwareSpreadRule',
      'prefer_null_aware_spread',
      () => PreferNullAwareSpreadRule(),
    );

    testRule(
      'PreferVisibleForTestingOnMembersRule',
      'prefer_visible_for_testing_on_members',
      () => PreferVisibleForTestingOnMembersRule(),
    );

    testRule(
      'AvoidAlwaysNullParametersRule',
      'avoid_always_null_parameters',
      () => AvoidAlwaysNullParametersRule(),
    );

    testRule(
      'AvoidAssigningToStaticFieldRule',
      'avoid_assigning_to_static_field',
      () => AvoidAssigningToStaticFieldRule(),
    );

    testRule(
      'AvoidAsyncCallInSyncFunctionRule',
      'avoid_async_call_in_sync_function',
      () => AvoidAsyncCallInSyncFunctionRule(),
    );

    testRule(
      'AvoidComplexLoopConditionsRule',
      'avoid_complex_loop_conditions',
      () => AvoidComplexLoopConditionsRule(),
    );

    testRule(
      'AvoidConstantConditionsRule',
      'avoid_constant_conditions',
      () => AvoidConstantConditionsRule(),
    );

    testRule(
      'AvoidContradictoryExpressionsRule',
      'avoid_contradictory_expressions',
      () => AvoidContradictoryExpressionsRule(),
    );

    testRule(
      'AvoidIdenticalExceptionHandlingBlocksRule',
      'avoid_identical_exception_handling_blocks',
      () => AvoidIdenticalExceptionHandlingBlocksRule(),
    );

    testRule(
      'AvoidLateFinalReassignmentRule',
      'avoid_late_final_reassignment',
      () => AvoidLateFinalReassignmentRule(),
    );

    testRule(
      'AvoidMissingCompleterStackTraceRule',
      'avoid_missing_completer_stack_trace',
      () => AvoidMissingCompleterStackTraceRule(),
    );

    testRule(
      'AvoidMissingEnumConstantInMapRule',
      'avoid_missing_enum_constant_in_map',
      () => AvoidMissingEnumConstantInMapRule(),
    );

    testRule(
      'AvoidParameterReassignmentRule',
      'avoid_parameter_reassignment',
      () => AvoidParameterReassignmentRule(),
    );

    testRule(
      'AvoidParameterMutationRule',
      'avoid_parameter_mutation',
      () => AvoidParameterMutationRule(),
    );

    testRule(
      'AvoidSimilarNamesRule',
      'avoid_similar_names',
      () => AvoidSimilarNamesRule(),
    );

    testRule(
      'AvoidUnnecessaryNullableParametersRule',
      'avoid_unnecessary_nullable_parameters',
      () => AvoidUnnecessaryNullableParametersRule(),
    );

    testRule(
      'FunctionAlwaysReturnsNullRule',
      'function_always_returns_null',
      () => FunctionAlwaysReturnsNullRule(),
    );

    testRule(
      'AvoidAccessingCollectionsByConstantIndexRule',
      'avoid_accessing_collections_by_constant_index',
      () => AvoidAccessingCollectionsByConstantIndexRule(),
    );

    testRule(
      'AvoidDefaultToStringRule',
      'avoid_default_tostring',
      () => AvoidDefaultToStringRule(),
    );

    testRule(
      'AvoidDuplicateConstantValuesRule',
      'avoid_duplicate_constant_values',
      () => AvoidDuplicateConstantValuesRule(),
    );

    testRule(
      'AvoidDuplicateInitializersRule',
      'avoid_duplicate_initializers',
      () => AvoidDuplicateInitializersRule(),
    );

    testRule(
      'AvoidUnnecessaryOverridesRule',
      'avoid_unnecessary_overrides',
      () => AvoidUnnecessaryOverridesRule(),
    );

    testRule(
      'AvoidUnnecessaryStatementsRule',
      'avoid_unnecessary_statements',
      () => AvoidUnnecessaryStatementsRule(),
    );

    testRule(
      'AvoidUnusedAssignmentRule',
      'avoid_unused_assignment',
      () => AvoidUnusedAssignmentRule(),
    );

    testRule(
      'AvoidUnusedInstancesRule',
      'avoid_unused_instances',
      () => AvoidUnusedInstancesRule(),
    );

    testRule(
      'AvoidUnusedAfterNullCheckRule',
      'avoid_unused_after_null_check',
      () => AvoidUnusedAfterNullCheckRule(),
    );

    testRule(
      'AvoidWildcardCasesWithEnumsRule',
      'avoid_wildcard_cases_with_enums',
      () => AvoidWildcardCasesWithEnumsRule(),
    );

    testRule(
      'FunctionAlwaysReturnsSameValueRule',
      'function_always_returns_same_value',
      () => FunctionAlwaysReturnsSameValueRule(),
    );

    testRule(
      'NoEqualNestedConditionsRule',
      'no_equal_nested_conditions',
      () => NoEqualNestedConditionsRule(),
    );

    testRule(
      'NoEqualSwitchCaseRule',
      'no_equal_switch_case',
      () => NoEqualSwitchCaseRule(),
    );

    testRule(
      'PreferAnyOrEveryRule',
      'prefer_any_or_every',
      () => PreferAnyOrEveryRule(),
    );

    testRule('PreferForInRule', 'prefer_for_in', () => PreferForInRule());

    testRule(
      'AvoidDuplicatePatternsRule',
      'avoid_duplicate_patterns',
      () => AvoidDuplicatePatternsRule(),
    );

    testRule(
      'AvoidNestedExtensionTypesRule',
      'avoid_nested_extension_types',
      () => AvoidNestedExtensionTypesRule(),
    );

    testRule(
      'AvoidSlowCollectionMethodsRule',
      'avoid_slow_collection_methods',
      () => AvoidSlowCollectionMethodsRule(),
    );

    testRule(
      'AvoidUnassignedFieldsRule',
      'avoid_unassigned_fields',
      () => AvoidUnassignedFieldsRule(),
    );

    testRule(
      'AvoidUnassignedLateFieldsRule',
      'avoid_unassigned_late_fields',
      () => AvoidUnassignedLateFieldsRule(),
    );

    testRule(
      'AvoidUnnecessaryLateFieldsRule',
      'avoid_unnecessary_late_fields',
      () => AvoidUnnecessaryLateFieldsRule(),
    );

    testRule(
      'AvoidUnnecessaryNullableFieldsRule',
      'avoid_unnecessary_nullable_fields',
      () => AvoidUnnecessaryNullableFieldsRule(),
    );

    testRule(
      'AvoidUnnecessaryPatternsRule',
      'avoid_unnecessary_patterns',
      () => AvoidUnnecessaryPatternsRule(),
    );

    testRule(
      'AvoidWildcardCasesWithSealedClassesRule',
      'avoid_wildcard_cases_with_sealed_classes',
      () => AvoidWildcardCasesWithSealedClassesRule(),
    );

    testRule(
      'RequireExhaustiveSealedSwitchRule',
      'require_exhaustive_sealed_switch',
      () => RequireExhaustiveSealedSwitchRule(),
    );

    testRule(
      'NoEqualSwitchExpressionCasesRule',
      'no_equal_switch_expression_cases',
      () => NoEqualSwitchExpressionCasesRule(),
    );

    testRule(
      'PreferBytesBuilderRule',
      'prefer_bytes_builder',
      () => PreferBytesBuilderRule(),
    );

    testRule(
      'PreferPushingConditionalExpressionsRule',
      'prefer_pushing_conditional_expressions',
      () => PreferPushingConditionalExpressionsRule(),
    );

    testRule(
      'PreferShorthandsWithConstructorsRule',
      'prefer_shorthands_with_constructors',
      () => PreferShorthandsWithConstructorsRule(),
    );

    testRule(
      'PreferShorthandsWithEnumsRule',
      'prefer_shorthands_with_enums',
      () => PreferShorthandsWithEnumsRule(),
    );

    testRule(
      'PreferShorthandsWithStaticFieldsRule',
      'prefer_shorthands_with_static_fields',
      () => PreferShorthandsWithStaticFieldsRule(),
    );

    testRule(
      'PassCorrectAcceptedTypeRule',
      'pass_correct_accepted_type',
      () => PassCorrectAcceptedTypeRule(),
    );

    testRule(
      'PassOptionalArgumentRule',
      'pass_optional_argument',
      () => PassOptionalArgumentRule(),
    );

    testRule(
      'PreferSingleDeclarationPerFileRule',
      'prefer_single_declaration_per_file',
      () => PreferSingleDeclarationPerFileRule(),
    );

    testRule(
      'PreferSwitchExpressionRule',
      'prefer_switch_expression',
      () => PreferSwitchExpressionRule(),
    );

    testRule(
      'PreferSwitchWithEnumsRule',
      'prefer_switch_with_enums',
      () => PreferSwitchWithEnumsRule(),
    );

    testRule(
      'PreferSwitchWithSealedClassesRule',
      'prefer_switch_with_sealed_classes',
      () => PreferSwitchWithSealedClassesRule(),
    );

    testRule(
      'PreferTestMatchersRule',
      'prefer_test_matchers',
      () => PreferTestMatchersRule(),
    );

    testRule(
      'PreferUnwrappingFutureOrRule',
      'prefer_unwrapping_future_or',
      () => PreferUnwrappingFutureOrRule(),
    );

    testRule(
      'AvoidInferrableTypeArgumentsRule',
      'prefer_inferred_type_arguments',
      () => AvoidInferrableTypeArgumentsRule(),
    );

    testRule(
      'AvoidPassingDefaultValuesRule',
      'avoid_passing_default_values',
      () => AvoidPassingDefaultValuesRule(),
    );

    testRule(
      'AvoidShadowedExtensionMethodsRule',
      'avoid_shadowed_extension_methods',
      () => AvoidShadowedExtensionMethodsRule(),
    );

    testRule(
      'AvoidUnnecessaryLocalLateRule',
      'avoid_unnecessary_local_late',
      () => AvoidUnnecessaryLocalLateRule(),
    );

    testRule(
      'MatchBaseClassDefaultValueRule',
      'match_base_class_default_value',
      () => MatchBaseClassDefaultValueRule(),
    );

    testRule(
      'MoveVariableCloserToUsageRule',
      'move_variable_closer_to_its_usage',
      () => MoveVariableCloserToUsageRule(),
    );

    testRule(
      'MoveVariableOutsideIterationRule',
      'move_variable_outside_iteration',
      () => MoveVariableOutsideIterationRule(),
    );

    testRule(
      'PreferOverridingParentEqualityRule',
      'prefer_overriding_parent_equality',
      () => PreferOverridingParentEqualityRule(),
    );

    testRule(
      'PreferSpecificCasesFirstRule',
      'prefer_specific_cases_first',
      () => PreferSpecificCasesFirstRule(),
    );

    testRule(
      'UseExistingDestructuringRule',
      'use_existing_destructuring',
      () => UseExistingDestructuringRule(),
    );

    testRule(
      'UseExistingVariableRule',
      'use_existing_variable',
      () => UseExistingVariableRule(),
    );

    testRule(
      'AvoidDuplicateStringLiteralsRule',
      'avoid_duplicate_string_literals',
      () => AvoidDuplicateStringLiteralsRule(),
    );

    testRule(
      'AvoidDuplicateStringLiteralsPairRule',
      'avoid_duplicate_string_literals_pair',
      () => AvoidDuplicateStringLiteralsPairRule(),
    );

    testRule(
      'AvoidExpensiveLogStringConstructionRule',
      'avoid_expensive_log_string_construction',
      () => AvoidExpensiveLogStringConstructionRule(),
    );

    testRule(
      'PreferTypedefsForCallbacksRule',
      'prefer_typedefs_for_callbacks',
      () => PreferTypedefsForCallbacksRule(),
    );

    testRule(
      'PreferRedirectingSuperclassConstructorRule',
      'prefer_redirecting_superclass_constructor',
      () => PreferRedirectingSuperclassConstructorRule(),
    );

    testRule(
      'AvoidEmptyBuildWhenRule',
      'avoid_empty_build_when',
      () => AvoidEmptyBuildWhenRule(),
    );

    testRule(
      'PreferUsePrefixRule',
      'prefer_use_prefix',
      () => PreferUsePrefixRule(),
    );

    testRule(
      'PreferLateFinalRule',
      'prefer_late_final',
      () => PreferLateFinalRule(),
    );

    testRule(
      'AvoidLateForNullableRule',
      'avoid_late_for_nullable',
      () => AvoidLateForNullableRule(),
    );

    testRule(
      'PreferDotShorthandRule',
      'prefer_dot_shorthand',
      () => PreferDotShorthandRule(),
    );

    testRule(
      'NoBooleanLiteralCompareRule',
      'no_boolean_literal_compare',
      () => NoBooleanLiteralCompareRule(),
    );

    testRule(
      'PreferReturningConditionalExpressionsRule',
      'prefer_returning_conditional_expressions',
      () => PreferReturningConditionalExpressionsRule(),
    );

    testRule(
      'AvoidMissingInterpolationRule',
      'avoid_missing_interpolation',
      () => AvoidMissingInterpolationRule(),
    );

    testRule(
      'AvoidIgnoringReturnValuesRule',
      'avoid_ignoring_return_values',
      () => AvoidIgnoringReturnValuesRule(),
    );

    testRule(
      'AvoidDeprecatedUsageRule',
      'avoid_deprecated_usage',
      () => AvoidDeprecatedUsageRule(),
    );

    testRule(
      'AvoidPositionalBooleanParametersRule',
      'avoid_positional_boolean_parameters',
      () => AvoidPositionalBooleanParametersRule(),
    );

    testRule(
      'PreferNamedBoolParamsRule',
      'prefer_named_bool_params',
      () => PreferNamedBoolParamsRule(),
    );

    testRule(
      'BannedUsageRule',
      'banned_identifier_usage',
      () => BannedUsageRule(),
    );
  });

  group('Code Quality Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_accessing_collections_by_constant_index',
      'avoid_adjacent_strings',
      'avoid_deprecated_usage',
      'avoid_inferrable_type_arguments',
      'avoid_always_null_parameters',
      'avoid_assigning_to_static_field',
      'avoid_async_call_in_sync_function',
      'avoid_complex_loop_conditions',
      'avoid_constant_conditions',
      'avoid_contradictory_expressions',
      'avoid_default_tostring',
      'avoid_expensive_log_string_construction',
      'avoid_duplicate_constant_values',
      'avoid_duplicate_initializers',
      'avoid_duplicate_patterns',
      'avoid_duplicate_string_literals',
      'avoid_duplicate_string_literals_pair',
      'avoid_empty_build_when',
      'avoid_enum_values_by_index',
      'avoid_identical_exception_handling_blocks',
      'avoid_incorrect_uri',
      'avoid_late_final_reassignment',
      'avoid_late_for_nullable',
      'avoid_late_keyword',
      'avoid_missed_calls',
      'avoid_missing_completer_stack_trace',
      'avoid_missing_enum_constant_in_map',
      'avoid_missing_interpolation',
      'avoid_misused_set_literals',
      'avoid_nested_extension_types',
      'avoid_parameter_mutation',
      'avoid_parameter_reassignment',
      'avoid_positional_boolean_parameters',
      'avoid_passing_default_values',
      'avoid_passing_self_as_argument',
      'avoid_recursive_calls',
      'avoid_recursive_tostring',
      'avoid_redundant_pragma_inline',
      'avoid_referencing_discarded_variables',
      'avoid_shadowed_extension_methods',
      'avoid_similar_names',
      'avoid_slow_collection_methods',
      'avoid_string_substring',
      'avoid_unassigned_fields',
      'avoid_unassigned_late_fields',
      'avoid_unknown_pragma',
      'banned_identifier_usage',
      'avoid_unnecessary_late_fields',
      'avoid_unnecessary_local_late',
      'avoid_unnecessary_nullable_fields',
      'avoid_unnecessary_nullable_parameters',
      'avoid_unnecessary_overrides',
      'avoid_unnecessary_patterns',
      'avoid_unnecessary_statements',
      'avoid_unused_after_null_check',
      'avoid_unused_assignment',
      'avoid_unused_instances',
      'avoid_unused_parameters',
      'avoid_weak_cryptographic_algorithms',
      'avoid_wildcard_cases_with_enums',
      'avoid_wildcard_cases_with_sealed_classes',
      'require_exhaustive_sealed_switch',
      'function_always_returns_null',
      'function_always_returns_same_value',
      'match_base_class_default_value',
      'missing_use_result_annotation',
      'move_variable_closer_to_its_usage',
      'move_variable_outside_iteration',
      'no_equal_nested_conditions',
      'no_equal_switch_case',
      'no_equal_switch_expression_cases',
      'no_object_declaration',
      'pass_correct_accepted_type',
      'pass_optional_argument',
      'prefer_any_or_every',
      'prefer_both_inlining_annotations',
      'prefer_bytes_builder',
      'prefer_dedicated_media_query_method',
      'prefer_dot_shorthand',
      'prefer_enums_by_name',
      'prefer_extracting_function_callbacks',
      'prefer_for_in',
      'prefer_inferred_type_arguments',
      'prefer_named_bool_params',
      'prefer_null_aware_spread',
      'prefer_overriding_parent_equality',
      'prefer_pushing_conditional_expressions',
      'prefer_redirecting_superclass_constructor',
      'prefer_shorthands_with_constructors',
      'prefer_shorthands_with_enums',
      'prefer_shorthands_with_static_fields',
      'prefer_single_declaration_per_file',
      'prefer_specific_cases_first',
      'prefer_switch_with_enums',
      'prefer_switch_with_sealed_classes',
      'prefer_test_matchers',
      'prefer_typedefs_for_callbacks',
      'prefer_unwrapping_future_or',
      'prefer_use_prefix',
      'prefer_visible_for_testing_on_members',
      'use_existing_destructuring',
      'use_existing_variable',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/code_quality/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior groups were removed. This file now keeps tests that
  // validate rule metadata and fixture presence instead of tautological asserts.
}
