/// Stylistic rule category data and ruleset definitions.
library;

import 'package:saropa_lints/src/tiers.dart' as tiers;


/// Stylistic rule categories, mirroring the organization in tiers.dart.
/// Used to generate the STYLISTIC RULES section in analysis_options_custom.yaml.
///
/// Categories containing "(conflicting - choose one)" in their name use a
/// pick-one UI in the walkthrough; all others are reviewed rule-by-rule.
const Map<String, List<String>> stylisticRuleCategories =
    <String, List<String>>{
  // ── Non-conflicting categories ──────────────────────────────────────
  'Debug/Test utility': <String>['prefer_fail_test_case'],
  'Ordering & Sorting': <String>[
    'prefer_member_ordering',
    'prefer_arguments_ordering',
    'prefer_sorted_parameters',
    'prefer_sorted_pattern_fields',
    'prefer_sorted_record_fields',
    'binary_expression_operand_order',
    'enforce_parameters_ordering',
    'enum_constants_ordering',
    'map_keys_ordering',
  ],
  'Naming conventions': <String>[
    'prefer_no_getter_prefix',
    'prefer_kebab_tag_name',
    'prefer_capitalized_comment_start',
    'prefer_snake_case_files',
    'prefer_camel_case_method_names',
    'prefer_exception_suffix',
    'prefer_error_suffix',
    'prefer_trailing_underscore_for_unused',
    'prefer_sliver_prefix',
    'prefer_correct_callback_field_name',
    'prefer_correct_handler_name',
    'prefer_correct_setter_parameter_name',
    'prefer_bloc_event_suffix',
    'prefer_bloc_state_suffix',
    'prefer_use_prefix',
  ],
  'Boolean naming': <String>[
    'prefer_boolean_prefixes',
    'prefer_descriptive_bool_names',
    'prefer_boolean_prefixes_for_params',
    'prefer_boolean_prefixes_for_locals',
  ],
  'Code style preferences': <String>[
    'prefer_no_continue_statement',
    'prefer_wildcard_for_unused_param',
    'prefer_rethrow_over_throw_e',
    'prefer_list_first',
    'prefer_list_last',
    'no_boolean_literal_compare',
    'prefer_returning_conditional_expressions',
    'prefer_duration_constants',
    'prefer_immediate_return',
    'prefer_for_in',
    'prefer_conditional_expressions',
    'prefer_returning_condition',
    'prefer_returning_conditionals',
    'prefer_returning_shorthands',
    'prefer_pushing_conditional_expressions',
    'prefer_getter_over_method',
  ],
  'Function & Parameter style': <String>[
    'prefer_arrow_functions',
    'prefer_all_named_parameters',
    'prefer_inline_callbacks',
    'avoid_parameter_reassignment',
  ],
  'Widget style': <String>[
    'avoid_shrink_wrap_in_scroll',
    'prefer_one_widget_per_file',
    'prefer_widget_methods_over_classes',
    'prefer_borderradius_circular',
    'avoid_small_text',
    'prefer_sized_box_square',
    'prefer_center_over_align',
    'prefer_spacing_over_sizedbox',
  ],
  'Class & Record style': <String>[
    'prefer_class_over_record_return',
    'prefer_private_underscore_prefix',
    'prefer_explicit_this',
  ],
  'Formatting': <String>[
    'prefer_blank_line_before_case',
    'prefer_blank_line_before_constructor',
    'prefer_blank_line_before_method',
    'prefer_blank_line_before_else',
    'prefer_blank_line_after_loop',
    'prefer_trailing_comma',
    'double_literal_format',
    'format_comment_style',
  ],
  'Comments & Documentation': <String>[
    'prefer_todo_format',
    'prefer_fixme_format',
    'prefer_sentence_case_comments',
    'prefer_period_after_doc',
    'prefer_doc_comments_over_regular',
    'prefer_no_commented_out_code',
  ],
  'Testing style': <String>['prefer_expect_over_assert_in_tests'],

  // ── Conflicting categories (pick one) ───────────────────────────────

  // Type & variable style
  'Type argument style (conflicting - choose one)': <String>[
    'prefer_inferred_type_arguments',
    'prefer_explicit_type_arguments',
  ],
  'Variable type style (conflicting - choose one)': <String>[
    'prefer_type_over_var',
    'prefer_var_over_explicit_type',
  ],
  'Dynamic vs Object (conflicting - choose one)': <String>[
    'prefer_dynamic_over_object',
    'prefer_object_over_dynamic',
  ],

  // Imports & strings
  'Import style (conflicting - choose one)': <String>[
    'prefer_absolute_imports',
    'prefer_flat_imports',
    'prefer_grouped_imports',
    'prefer_named_imports',
    'prefer_relative_imports',
  ],
  'Quote style (conflicting - choose one)': <String>[
    'prefer_double_quotes',
    'prefer_single_quotes',
  ],
  'Apostrophe style (conflicting - choose one)': <String>[
    'prefer_doc_curly_apostrophe',
    'prefer_doc_straight_apostrophe',
    'prefer_straight_apostrophe',
  ],
  'String building (conflicting - choose one)': <String>[
    'prefer_interpolation_over_concatenation',
    'prefer_concatenation_over_interpolation',
  ],

  // Control flow & error handling
  'Exit strategy (conflicting - choose one)': <String>[
    'prefer_early_return',
    'prefer_single_exit_point',
  ],
  'Boolean comparison (conflicting - choose one)': <String>[
    'prefer_implicit_boolean_comparison',
    'prefer_explicit_boolean_comparison',
  ],
  'Error handling (conflicting - choose one)': <String>[
    'prefer_catch_over_on',
    'prefer_on_over_catch',
  ],
  'Exception specificity (conflicting - choose one)': <String>[
    'prefer_specific_exceptions',
    'prefer_generic_exception',
  ],

  // Async & chaining
  'Async style (conflicting - choose one)': <String>[
    'prefer_await_over_then',
    'prefer_then_over_await',
  ],
  'Method chaining (conflicting - choose one)': <String>[
    'prefer_cascade_over_chained',
    'prefer_chained_over_cascade',
  ],

  // Collections & null handling
  'Spread vs addAll (conflicting - choose one)': <String>[
    'prefer_spread_over_addall',
    'prefer_addall_over_spread',
  ],
  'Collection conditionals (conflicting - choose one)': <String>[
    'prefer_collection_if_over_ternary',
    'prefer_ternary_over_collection_if',
  ],
  'Null ternary (conflicting - choose one)': <String>[
    'prefer_if_null_over_ternary',
    'prefer_ternary_over_if_null',
  ],
  'Null assignment (conflicting - choose one)': <String>[
    'prefer_null_aware_assignment',
    'prefer_explicit_null_assignment',
  ],
  'Nullable vs late (conflicting - choose one)': <String>[
    'prefer_nullable_over_late',
    'prefer_late_over_nullable',
  ],

  // Ordering & naming
  'Member ordering (conflicting - choose one)': <String>[
    'prefer_static_members_first',
    'prefer_instance_members_first',
    'prefer_public_members_first',
    'prefer_private_members_first',
  ],
  'Field/method order (conflicting - choose one)': <String>[
    'prefer_fields_before_methods',
    'prefer_methods_before_fields',
  ],
  'Constant case (conflicting - choose one)': <String>[
    'prefer_lower_camel_case_constants',
    'prefer_screaming_case_constants',
  ],

  // Formatting & spacing
  'Trailing comma (conflicting - choose one)': <String>[
    'prefer_trailing_comma_always',
    'unnecessary_trailing_comma',
  ],
  'Blank line before return (conflicting - choose one)': <String>[
    'prefer_blank_line_before_return',
    'prefer_no_blank_line_before_return',
  ],
  'Declaration spacing (conflicting - choose one)': <String>[
    'prefer_blank_line_after_declarations',
    'prefer_compact_declarations',
  ],
  'Member spacing (conflicting - choose one)': <String>[
    'prefer_blank_lines_between_members',
    'prefer_compact_class_members',
  ],

  // Widget conflicts
  'Container vs SizedBox (conflicting - choose one)': <String>[
    'prefer_sizedbox_over_container',
    'prefer_container_over_sizedbox',
  ],
  'Expanded vs Flexible (conflicting - choose one)': <String>[
    'prefer_expanded_over_flexible',
    'prefer_flexible_over_expanded',
  ],
  'EdgeInsets style (conflicting - choose one)': <String>[
    'prefer_edgeinsets_symmetric',
    'prefer_edgeinsets_only',
  ],
  'RichText widget (conflicting - choose one)': <String>[
    'prefer_text_rich_over_richtext',
    'prefer_richtext_over_text_rich',
  ],
  'Theme colors (conflicting - choose one)': <String>[
    'prefer_material_theme_colors',
    'prefer_explicit_colors',
  ],

  // Testing conflicts
  'Test naming (conflicting - choose one)': <String>[
    'prefer_test_name_should_when',
    'prefer_test_name_descriptive',
  ],
  'Test comments (conflicting - choose one)': <String>[
    'prefer_given_when_then_comments',
    'prefer_self_documenting_tests',
  ],
  'Test expectations (conflicting - choose one)': <String>[
    'prefer_single_expectation_per_test',
    'prefer_grouped_expectations',
  ],

  // ── Remaining opinionated rules (no conflicts) ─────────────────────
  'Opinionated rules': <String>[
    'prefer_clip_r_superellipse',
    'prefer_clip_r_superellipse_clipper',
    'prefer_concise_variable_names',
    'prefer_constructor_assertion',
    'prefer_constructor_body_assignment',
    'prefer_curly_apostrophe',
    'prefer_default_enum_case',
    'prefer_descriptive_bool_names_strict',
    'prefer_descriptive_variable_names',
    'prefer_dot_shorthand',
    'prefer_exhaustive_enums',
    'prefer_explicit_types',
    'prefer_factory_for_validation',
    'prefer_fake_over_mock',
    'prefer_future_void_function_over_async_callback',
    'prefer_grouped_by_purpose',
    'prefer_guard_clauses',
    'prefer_initializing_formals',
    'prefer_keys_with_lookup',
    'prefer_map_entries_iteration',
    'prefer_mutable_collections',
    'prefer_no_blank_line_inside_blocks',
    'prefer_positive_conditions',
    'prefer_positive_conditions_first',
    'prefer_record_over_equatable',
    'prefer_required_before_optional',
    'prefer_single_blank_line_max',
    'prefer_super_parameters',
    'prefer_switch_statement',
    'prefer_sync_over_async_where_possible',
    'prefer_test_data_builder',
    'prefer_wheretype_over_where_is',
  ],
};

/// Rule names for the "Good methods" major group (doc/guides/good_methods.md).
/// Excludes any rule that conflicts with another in the same group.
const Set<String> goodMethodsRuleNames = <String>{
  'prefer_doc_comments_over_regular',
  'prefer_period_after_doc',
  'prefer_sentence_case_comments',
  'prefer_capitalized_comment_start',
  'prefer_todo_format',
  'prefer_fixme_format',
  'prefer_no_commented_out_code',
  'prefer_blank_line_before_method',
  'prefer_blank_lines_between_members',
  'prefer_blank_line_before_constructor',
  'prefer_blank_line_before_case',
  'prefer_blank_line_before_return',
  'prefer_blank_line_before_else',
  'prefer_blank_line_after_loop',
  'prefer_blank_line_after_declarations',
  'prefer_readable_line_length',
  'prefer_single_blank_line_max',
};

/// Ids for stylistic rulesets shown in the init wizard (one question per ruleset).
enum StylisticRulesetId {
  goodMethods,
  orderingAndSorting,
  namingConventions,
  booleanNaming,
  codeStyle,
  functionAndParameterStyle,
  widgetStyle,
  classAndRecordStyle,
  formatting,
  commentsAndDocumentation,
  testingStyle,
  debugTestUtility,
  opinionatedRules,
  other,
}

/// One stylistic ruleset: user-facing label, short description, and rule names.
class StylisticRuleset {
  const StylisticRuleset({
    required this.id,
    required this.label,
    required this.description,
    required this.rules,
  });

  final StylisticRulesetId id;
  final String label;
  final String description;
  final Set<String> rules;
}

/// Stylistic rulesets: one question per ruleset (~13–14 total).
/// Order matters; rules can appear in more than one ruleset (no contradict).
List<StylisticRuleset> getStylisticRulesets() {
  final cat = stylisticRuleCategories;
  Set<String> catRules(String key) =>
      (cat[key] ?? (throw StateError('Missing stylistic category: $key')))
          .toSet();
  return <StylisticRuleset>[
    StylisticRuleset(
      id: StylisticRulesetId.goodMethods,
      label: 'Good methods',
      description:
          'Enforces clear, maintainable methods: doc comments (/// with period), '
          'spacing (blank lines before methods, returns, else, after loops), '
          'readable line length, TODO/FIXME format, and no commented-out code. '
          'Full guide: doc/guides/good_methods.md in the package.',
      rules: Set<String>.from(goodMethodsRuleNames),
    ),
    StylisticRuleset(
      id: StylisticRulesetId.orderingAndSorting,
      label: 'Ordering & sorting',
      description:
          'Keeps code predictable: member order, argument order, sorted '
          'parameters and pattern/record fields, operand order in expressions, '
          'enum constants, and map keys. '
          'Warning: Very noisy on large codebases—hundreds or thousands of '
          'hits until you reorder. Prefer enabling on new code or small repos.',
      rules: catRules('Ordering & Sorting'),
    ),
    StylisticRuleset(
      id: StylisticRulesetId.namingConventions,
      label: 'Naming conventions',
      description:
          'Names for files (snake_case), methods (camelCase), exceptions and '
          'errors (suffixes), callbacks and handlers, setters, and Bloc events '
          'and state. Also sliver prefix, unused trailing underscore, and '
          'use_ prefix. '
          'Warning: Can be noisy on large codebases; consider enabling '
          'incrementally or for new code only.',
      rules: catRules('Naming conventions'),
    ),
    StylisticRuleset(
      id: StylisticRulesetId.booleanNaming,
      label: 'Boolean naming',
      description:
          'Booleans must use clear prefixes (is/has/can/should/will/did) or '
          'suffixes so intent is obvious. Applies to parameters, local '
          'variables, and fields. Reduces ambiguity in conditionals and APIs.',
      rules: catRules('Boolean naming'),
    ),
    StylisticRuleset(
      id: StylisticRulesetId.codeStyle,
      label: 'Code style',
      description:
          'How you write returns, conditionals, loops, and expressions: '
          'immediate return, returning conditionals, for-in, list first/last, '
          'duration constants, no continue, rethrow, getter vs method. '
          'Encourages readable control flow and shorthands.',
      rules: catRules('Code style preferences'),
    ),
    StylisticRuleset(
      id: StylisticRulesetId.functionAndParameterStyle,
      label: 'Functions & parameters',
      description: 'Arrow functions when concise, all-named parameters, inline '
          'callbacks, and no parameter reassignment. Affects how you define '
          'and call functions and how you pass callbacks.',
      rules: catRules('Function & Parameter style'),
    ),
    StylisticRuleset(
      id: StylisticRulesetId.widgetStyle,
      label: 'Widget style',
      description:
          'Flutter widget choices: avoid shrinkWrap in scroll, one widget per '
          'file, widget methods over classes, BorderRadius.circular, avoid small '
          'text, SizedBox.square, center over align, spacing over SizedBox. '
          'Only relevant for Flutter projects.',
      rules: catRules('Widget style'),
    ),
    StylisticRuleset(
      id: StylisticRulesetId.classAndRecordStyle,
      label: 'Classes & records',
      description:
          'When to use class vs record return types, private underscore '
          'prefix for library-private members, and explicit this where it '
          'improves clarity. Applies to Dart 3 records and class design.',
      rules: catRules('Class & Record style'),
    ),
    StylisticRuleset(
      id: StylisticRulesetId.formatting,
      label: 'Formatting',
      description:
          'Blank lines before case/constructor/method/else, after loop; '
          'trailing comma; double literal format; comment style. Complements '
          'Good methods on spacing and keeps literals and comments consistent. '
          'Warning: Can be noisy on large codebases; many files may need edits.',
      rules: catRules('Formatting'),
    ),
    StylisticRuleset(
      id: StylisticRulesetId.commentsAndDocumentation,
      label: 'Comments & documentation',
      description:
          'TODO and FIXME must follow a standard format (e.g. TODO(author): '
          'text). Sentence case and period after doc comments; prefer /// over '
          '// for docs; no commented-out code. Overlaps with Good methods.',
      rules: catRules('Comments & Documentation'),
    ),
    StylisticRuleset(
      id: StylisticRulesetId.testingStyle,
      label: 'Testing style',
      description:
          'Prefer expect over assert in tests so failures show expected vs '
          'actual. Improves test output and aligns with common test style.',
      rules: catRules('Testing style'),
    ),
    StylisticRuleset(
      id: StylisticRulesetId.debugTestUtility,
      label: 'Debug & test utility',
      description:
          'Helpers like prefer_fail_test_case so tests fail with a clear '
          'message when they hit an unexpected path. Useful for test '
          'structure and debugging test failures.',
      rules: catRules('Debug/Test utility'),
    ),
    StylisticRuleset(
      id: StylisticRulesetId.opinionatedRules,
      label: 'Opinionated rules',
      description:
          'Extra style choices: superellipse clipper, concise names, constructor '
          'assertions, curly apostrophe, exhaustive enums, factory for '
          'validation, guard clauses, initializing formals, positive conditions, '
          'and more. '
          'Warning: Many rules; can be noisy. Enable selectively or for new code.',
      rules: catRules('Opinionated rules'),
    ),
    // Rules not in any category above (covers all stylistic rules)
    ...() {
      final allCategorized = <String>{};
      for (final list in cat.values) {
        allCategorized.addAll(list);
      }
      final otherRules =
          tiers.stylisticRules.difference(allCategorized).toList()..sort();
      if (otherRules.isEmpty) return <StylisticRuleset>[];
      return <StylisticRuleset>[
        StylisticRuleset(
          id: StylisticRulesetId.other,
          label: 'Other stylistic rules',
          description:
              'Rules not in any named ruleset above (e.g. newer rules). '
              'The list of rule names is shown below so you can decide. '
              'Enable all only if you want to try them; you can disable '
              'individual rules later in your config.',
          rules: otherRules.toSet(),
        ),
      ];
    }(),
  ];
}
