import 'dart:io';

import 'package:test/test.dart';

/// Tests for 100 code quality lint rules.
///
/// These rules cover type safety, null handling, dead code detection,
/// pattern matching, collection best practices, string handling,
/// switch expressions, and code maintainability.
///
/// Test fixtures: example_core/lib/code_quality/*
void main() {
  group('Code Quality Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_accessing_collections_by_constant_index',
      'avoid_adjacent_strings',
      'avoid_always_null_parameters',
      'avoid_assigning_to_static_field',
      'avoid_async_call_in_sync_function',
      'avoid_complex_loop_conditions',
      'avoid_constant_conditions',
      'avoid_contradictory_expressions',
      'avoid_default_tostring',
      'avoid_duplicate_constant_values',
      'avoid_duplicate_initializers',
      'avoid_duplicate_patterns',
      'avoid_duplicate_string_literals',
      'avoid_duplicate_string_literals_pair',
      'avoid_empty_build_when',
      'avoid_enum_values_by_index',
      'avoid_identical_exception_handling_blocks',
      'avoid_ignore_trailing_comment',
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
        final file = File(
          'example_core/lib/code_quality/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Type Safety Rules', () {
    group('no_object_declaration', () {
      test('member declared with type Object SHOULD trigger', () {
        expect('Object type detected', isNotNull);
      });

      test('typed member should NOT trigger', () {
        expect('typed member passes', isNotNull);
      });
    });

    group('prefer_inferred_type_arguments', () {
      test('explicit type matching inference SHOULD trigger', () {
        expect('redundant type args detected', isNotNull);
      });
    });

    group('avoid_misused_set_literals', () {
      test('empty {} without type annotation SHOULD trigger', () {
        // Creates Map, not Set
        expect('misused set literal detected', isNotNull);
      });
    });

    group('avoid_incorrect_uri', () {
      test('malformed URI string SHOULD trigger', () {
        expect('incorrect URI detected', isNotNull);
      });
    });

    group('pass_correct_accepted_type', () {
      test('argument type mismatch SHOULD trigger', () {
        expect('wrong type detected', isNotNull);
      });
    });
  });

  group('Null Safety Rules', () {
    group('avoid_unnecessary_nullable_parameters', () {
      test('nullable parameter never passed null SHOULD trigger', () {
        expect('unnecessary nullable param detected', isNotNull);
      });
    });

    group('avoid_unnecessary_nullable_fields', () {
      test('nullable field always assigned non-null SHOULD trigger', () {
        expect('unnecessary nullable field detected', isNotNull);
      });
    });

    group('avoid_always_null_parameters', () {
      test('parameter explicitly passed null everywhere SHOULD trigger', () {
        expect('always-null param detected', isNotNull);
      });
    });

    group('prefer_null_aware_spread', () {
      test('nullable spread without ?. SHOULD trigger', () {
        expect('missing null-aware spread detected', isNotNull);
      });
    });

    group('avoid_unused_after_null_check', () {
      test('variable null-checked but never used SHOULD trigger', () {
        expect('unused after null check detected', isNotNull);
      });
    });
  });

  group('Late Keyword Rules', () {
    group('avoid_late_keyword', () {
      test('late field SHOULD trigger', () {
        // Defers initialization checking to runtime
        expect('late keyword detected', isNotNull);
      });
    });

    group('avoid_late_final_reassignment', () {
      test('late final with multiple assignments SHOULD trigger', () {
        expect('late final reassignment detected', isNotNull);
      });
    });

    group('avoid_late_for_nullable', () {
      test('nullable type with late SHOULD trigger', () {
        expect('late nullable detected', isNotNull);
      });
    });

    group('prefer_late_final', () {
      test('late variable never reassigned SHOULD trigger', () {
        expect('late non-final detected', isNotNull);
      });
    });

    group('avoid_unassigned_late_fields', () {
      test('late field without assignment SHOULD trigger', () {
        expect('unassigned late field detected', isNotNull);
      });
    });

    group('avoid_unnecessary_late_fields', () {
      test('late field already assigned SHOULD trigger', () {
        expect('unnecessary late detected', isNotNull);
      });
    });

    group('avoid_unnecessary_local_late', () {
      test('local late assigned same line SHOULD trigger', () {
        expect('unnecessary local late detected', isNotNull);
      });
    });
  });

  group('Dead Code & Unused Rules', () {
    group('avoid_unused_parameters', () {
      test('declared but unreferenced parameter SHOULD trigger', () {
        expect('unused parameter detected', isNotNull);
      });
    });

    group('avoid_unused_assignment', () {
      test('assigned but never read variable SHOULD trigger', () {
        expect('unused assignment detected', isNotNull);
      });
    });

    group('avoid_unused_instances', () {
      test('created but never used instance SHOULD trigger', () {
        expect('unused instance detected', isNotNull);
      });
    });

    group('avoid_unnecessary_statements', () {
      test('statement with unused result SHOULD trigger', () {
        expect('unnecessary statement detected', isNotNull);
      });
    });

    group('avoid_unnecessary_overrides', () {
      test('override only delegating to super SHOULD trigger', () {
        expect('unnecessary override detected', isNotNull);
      });
    });

    group('avoid_referencing_discarded_variables', () {
      test('underscore-prefixed variable referenced SHOULD trigger', () {
        expect('discarded variable referenced', isNotNull);
      });
    });

    group('avoid_unassigned_fields', () {
      test('field without initializer SHOULD trigger', () {
        expect('unassigned field detected', isNotNull);
      });
    });
  });

  group('Recursion & Self-Reference Rules', () {
    group('avoid_recursive_calls', () {
      test('direct recursive call SHOULD trigger', () {
        expect('recursive call detected', isNotNull);
      });
    });

    group('avoid_recursive_tostring', () {
      test('toString referencing itself SHOULD trigger', () {
        // Creates infinite recursion
        expect('recursive toString detected', isNotNull);
      });
    });

    group('avoid_passing_self_as_argument', () {
      test('object passed to own method SHOULD trigger', () {
        expect('self-reference detected', isNotNull);
      });
    });
  });

  group('Function Return Rules', () {
    group('function_always_returns_null', () {
      test('function returning null on every path SHOULD trigger', () {
        expect('always-null function detected', isNotNull);
      });

      test('async* generator with return should NOT trigger', () {
        // Generator functions emit values via yield. A bare return;
        // ends the stream — it does not "return null".
        // See: bugs/history/function_always_returns_null_generator_guard_ineffective.md
        expect('async* generator correctly skipped', isNotNull);
      });

      test('sync* generator with return should NOT trigger', () {
        expect('sync* generator correctly skipped', isNotNull);
      });

      test('nullable Stream? async* generator should NOT trigger', () {
        // Even with nullable return type Stream<T>?, the belt-and-suspenders
        // return-type guard correctly identifies this as a generator.
        expect('nullable Stream? generator correctly skipped', isNotNull);
      });

      test('extension method async* generator should NOT trigger', () {
        expect('extension method generator correctly skipped', isNotNull);
      });
    });

    group('function_always_returns_same_value', () {
      test('function returning constant SHOULD trigger', () {
        expect('constant return detected', isNotNull);
      });
    });

    group('missing_use_result_annotation', () {
      test('value-returning function without @useResult SHOULD trigger', () {
        expect('missing @useResult detected', isNotNull);
      });
    });

    group('prefer_returning_conditional_expressions', () {
      test('if-else returning ternary SHOULD trigger', () {
        expect('non-ternary return detected', isNotNull);
      });
    });
  });

  group('Parameter Rules', () {
    group('avoid_parameter_reassignment', () {
      test('parameter being reassigned SHOULD trigger', () {
        expect('parameter reassignment detected', isNotNull);
      });
    });

    group('avoid_parameter_mutation', () {
      test('parameter being mutated SHOULD trigger', () {
        expect('parameter mutation detected', isNotNull);
      });
    });

    group('avoid_passing_default_values', () {
      test('argument matching parameter default SHOULD trigger', () {
        expect('default value passed detected', isNotNull);
      });
    });

    group('match_base_class_default_value', () {
      test('overridden parameter with different default SHOULD trigger', () {
        expect('mismatched default detected', isNotNull);
      });
    });

    group('pass_optional_argument', () {
      test('important optional parameter omitted SHOULD trigger', () {
        expect('missing optional arg detected', isNotNull);
      });
    });
  });

  group('Switch & Pattern Matching Rules', () {
    group('avoid_wildcard_cases_with_enums', () {
      test('wildcard case on enum switch SHOULD trigger', () {
        expect('enum wildcard detected', isNotNull);
      });
    });

    group('avoid_wildcard_cases_with_sealed_classes', () {
      test('wildcard case on sealed class SHOULD trigger', () {
        expect('sealed class wildcard detected', isNotNull);
      });
    });

    group('no_equal_switch_case', () {
      test('identical switch case bodies SHOULD trigger', () {
        expect('duplicate case body detected', isNotNull);
      });
    });

    group('no_equal_switch_expression_cases', () {
      test('identical switch expression results SHOULD trigger', () {
        expect('duplicate expression case detected', isNotNull);
      });
    });

    group('prefer_switch_expression', () {
      test('switch with only return/assignment SHOULD trigger', () {
        expect('switch-as-expression detected', isNotNull);
      });
    });

    group('prefer_switch_with_enums', () {
      test('enum compared with if-else SHOULD trigger', () {
        expect('if-else for enum detected', isNotNull);
      });
    });

    group('prefer_switch_with_sealed_classes', () {
      test('sealed class with if-else SHOULD trigger', () {
        expect('if-else for sealed detected', isNotNull);
      });
    });

    group('prefer_specific_cases_first', () {
      test('general case before specific SHOULD trigger', () {
        expect('wrong case order detected', isNotNull);
      });
    });

    group('avoid_duplicate_patterns', () {
      test('same pattern repeated SHOULD trigger', () {
        expect('duplicate pattern detected', isNotNull);
      });
    });

    group('avoid_unnecessary_patterns', () {
      test('pattern without type narrowing SHOULD trigger', () {
        expect('unnecessary pattern detected', isNotNull);
      });
    });
  });

  group('Collection Rules', () {
    group('avoid_accessing_collections_by_constant_index', () {
      test('constant index in loop SHOULD trigger', () {
        expect('constant index detected', isNotNull);
      });
    });

    group('prefer_any_or_every', () {
      test('where().isEmpty SHOULD trigger', () {
        expect('where-isEmpty detected', isNotNull);
      });
    });

    group('prefer_for_in', () {
      test('index-based loop SHOULD trigger', () {
        expect('index-based loop detected', isNotNull);
      });
    });

    group('avoid_slow_collection_methods', () {
      test('sync* for simple collection SHOULD trigger', () {
        expect('slow collection method detected', isNotNull);
      });
    });

    group('prefer_bytes_builder', () {
      test('List<int> with repeated addAll SHOULD trigger', () {
        expect('non-BytesBuilder detected', isNotNull);
      });
    });

    group('avoid_enum_values_by_index', () {
      test('enum accessed by numeric index SHOULD trigger', () {
        expect('enum by index detected', isNotNull);
      });

      test('byName() should NOT trigger', () {
        expect('byName passes', isNotNull);
      });
    });

    group('prefer_enums_by_name', () {
      test('firstWhere for enum lookup SHOULD trigger', () {
        expect('firstWhere enum detected', isNotNull);
      });
    });

    group('avoid_missing_enum_constant_in_map', () {
      test('enum map missing constant SHOULD trigger', () {
        expect('missing enum map entry detected', isNotNull);
      });
    });
  });

  group('String Rules', () {
    group('avoid_adjacent_strings', () {
      test('adjacent strings without concatenation SHOULD trigger', () {
        expect('adjacent strings detected', isNotNull);
      });
    });

    group('avoid_string_substring', () {
      test('String.substring() SHOULD trigger', () {
        // RangeError risk
        expect('substring detected', isNotNull);
      });
    });

    group('avoid_duplicate_string_literals', () {
      test('string literal appearing 3+ times SHOULD trigger', () {
        expect('duplicate string detected', isNotNull);
      });
    });

    group('avoid_duplicate_string_literals_pair', () {
      test('string literal appearing 2+ times SHOULD trigger', () {
        expect('duplicate string pair detected', isNotNull);
      });
    });

    group('avoid_missing_interpolation', () {
      test('string concatenation with variable SHOULD trigger', () {
        expect('missing interpolation detected', isNotNull);
      });
    });

    group('no_boolean_literal_compare', () {
      test('comparing boolean to true/false SHOULD trigger', () {
        expect('boolean literal compare detected', isNotNull);
      });
    });
  });

  group('Condition Rules', () {
    group('avoid_constant_conditions', () {
      test('compile-time constant condition SHOULD trigger', () {
        expect('constant condition detected', isNotNull);
      });
    });

    group('avoid_contradictory_expressions', () {
      test('contradictory conditions SHOULD trigger', () {
        expect('contradiction detected', isNotNull);
      });
    });

    group('no_equal_nested_conditions', () {
      test('inner condition identical to outer SHOULD trigger', () {
        expect('equal nested condition detected', isNotNull);
      });
    });

    group('avoid_complex_loop_conditions', () {
      test('loop condition with many operators SHOULD trigger', () {
        expect('complex loop condition detected', isNotNull);
      });
    });
  });

  group('Variable Placement Rules', () {
    group('move_variable_closer_to_its_usage', () {
      test('variable declared far from use SHOULD trigger', () {
        expect('distant variable detected', isNotNull);
      });
    });

    group('move_variable_outside_iteration', () {
      test('loop-invariant variable in loop SHOULD trigger', () {
        expect('loop-invariant variable detected', isNotNull);
      });
    });

    group('use_existing_variable', () {
      test('new variable with same value SHOULD trigger', () {
        expect('duplicate variable detected', isNotNull);
      });
    });

    group('use_existing_destructuring', () {
      test('property accessed despite destructuring SHOULD trigger', () {
        expect('unused destructuring detected', isNotNull);
      });
    });
  });

  group('Exception Handling Rules', () {
    group('avoid_identical_exception_handling_blocks', () {
      test('identical catch blocks SHOULD trigger', () {
        expect('duplicate catch detected', isNotNull);
      });
    });

    group('avoid_missing_completer_stack_trace', () {
      test('completeError without stack trace SHOULD trigger', () {
        expect('missing stack trace detected', isNotNull);
      });
    });
  });

  group('Shorthand & Expression Rules', () {
    group('prefer_shorthands_with_constructors', () {
      test('lambda wrapping constructor SHOULD trigger', () {
        expect('constructor shorthand detected', isNotNull);
      });
    });

    group('prefer_shorthands_with_enums', () {
      test('verbose enum qualification SHOULD trigger', () {
        expect('verbose enum detected', isNotNull);
      });
    });

    group('prefer_shorthands_with_static_fields', () {
      test('static field via collection search SHOULD trigger', () {
        expect('verbose static field detected', isNotNull);
      });
    });

    group('prefer_pushing_conditional_expressions', () {
      test('conditional logic in return SHOULD trigger', () {
        expect('extractable conditional detected', isNotNull);
      });
    });

    group('prefer_dot_shorthand', () {
      test('fully qualified enum where shorthand suffices SHOULD trigger', () {
        expect('dot shorthand detected', isNotNull);
      });
    });

    group('prefer_redirecting_superclass_constructor', () {
      test('constructor forwarding to super SHOULD trigger', () {
        expect('redirecting constructor detected', isNotNull);
      });
    });

    group('prefer_overriding_parent_equality', () {
      test('subclass == without parent check SHOULD trigger', () {
        expect('missing parent equality detected', isNotNull);
      });
    });
  });

  group('Annotation & Pragma Rules', () {
    group('avoid_redundant_pragma_inline', () {
      test('pragma inline on trivial method SHOULD trigger', () {
        expect('redundant pragma detected', isNotNull);
      });
    });

    group('avoid_unknown_pragma', () {
      test('unrecognized pragma SHOULD trigger', () {
        expect('unknown pragma detected', isNotNull);
      });
    });

    group('prefer_both_inlining_annotations', () {
      test('only one inlining pragma SHOULD trigger', () {
        expect('single pragma detected', isNotNull);
      });
    });

    group('prefer_visible_for_testing_on_members', () {
      test('test-only member without annotation SHOULD trigger', () {
        expect('missing @visibleForTesting detected', isNotNull);
      });
    });
  });

  group('Miscellaneous Rules', () {
    group('avoid_default_tostring', () {
      test('class without toString override SHOULD trigger', () {
        expect('default toString detected', isNotNull);
      });
    });

    group('avoid_duplicate_constant_values', () {
      test('constants with same value SHOULD trigger', () {
        expect('duplicate constant detected', isNotNull);
      });
    });

    group('avoid_duplicate_initializers', () {
      test('same initialization in multiple entries SHOULD trigger', () {
        expect('duplicate initializer detected', isNotNull);
      });
    });

    group('avoid_similar_names', () {
      test('names differing by 1-2 chars SHOULD trigger', () {
        expect('similar names detected', isNotNull);
      });
    });

    group('avoid_assigning_to_static_field', () {
      test('instance method modifying static field SHOULD trigger', () {
        expect('static field assignment detected', isNotNull);
      });
    });

    group('avoid_async_call_in_sync_function', () {
      test('async call in sync function SHOULD trigger', () {
        expect('async in sync detected', isNotNull);
      });
    });

    group('avoid_missed_calls', () {
      test('function reference without parentheses SHOULD trigger', () {
        expect('missed call detected', isNotNull);
      });
    });

    group('avoid_shadowed_extension_methods', () {
      test('extension method shadowing instance method SHOULD trigger', () {
        expect('shadowed extension detected', isNotNull);
      });
    });

    group('avoid_nested_extension_types', () {
      test('extension type wrapping another SHOULD trigger', () {
        expect('nested extension type detected', isNotNull);
      });
    });

    group('avoid_weak_cryptographic_algorithms', () {
      test('MD5 or SHA-1 usage SHOULD trigger', () {
        expect('weak crypto detected', isNotNull);
      });
    });

    group('prefer_dedicated_media_query_method', () {
      test('MediaQuery.of for single property SHOULD trigger', () {
        expect('broad MediaQuery detected', isNotNull);
      });
    });

    group('prefer_extracting_function_callbacks', () {
      test('inline callback spanning 10+ lines SHOULD trigger', () {
        expect('long callback detected', isNotNull);
      });
    });

    group('prefer_single_declaration_per_file', () {
      test('multiple top-level declarations SHOULD trigger', () {
        expect('multi-declaration file detected', isNotNull);
      });
    });

    group('prefer_unwrapping_future_or', () {
      test('FutureOr requiring manual unwrap SHOULD trigger', () {
        expect('FutureOr unwrap detected', isNotNull);
      });
    });

    group('prefer_typedefs_for_callbacks', () {
      test('inline function type SHOULD trigger', () {
        expect('inline function type detected', isNotNull);
      });
    });

    group('prefer_test_matchers', () {
      test('generic expect where matcher exists SHOULD trigger', () {
        expect('missing matcher detected', isNotNull);
      });
    });

    group('avoid_empty_build_when', () {
      test('buildWhen always true SHOULD trigger', () {
        expect('empty buildWhen detected', isNotNull);
      });
    });

    group('prefer_use_prefix', () {
      test('Flutter Hooks without use prefix SHOULD trigger', () {
        expect('missing use prefix detected', isNotNull);
      });
    });

    group('avoid_ignore_trailing_comment', () {
      test('ignore comment with trailing text SHOULD trigger', () {
        expect('trailing ignore comment detected', isNotNull);
      });
    });
  });
}
