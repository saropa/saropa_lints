/// Tier-based rule configuration for saropa_lints.
///
/// Each tier builds on the previous one:
/// - essential: Critical rules (~45 rules) - prevents crashes, security issues
/// - recommended: Essential + common mistakes (~150 rules) - default for most teams
/// - professional: Recommended + architecture/testing (~350 rules) - enterprise teams
/// - comprehensive: Professional + thorough coverage (~700 rules) - quality obsessed
/// - insanity: Everything (~475+ rules) - greenfield projects
library;

/// Essential tier rules - Critical rules that prevent crashes, data loss, and security holes.
const Set<String> essentialRules = <String>{
  // Memory Leaks - Controllers (dispose)
  'require_dispose',
  'dispose_fields',
  'require_animation_disposal',
  'avoid_undisposed_instances',
  'require_value_notifier_dispose',
  // Memory Leaks - Timers & Subscriptions (cancel)
  'require_timer_cancellation',
  'avoid_unassigned_stream_subscriptions',
  // Memory Leaks - Streams (close)
  'require_stream_controller_dispose',
  // Memory Leaks - Listeners
  'always_remove_listener',

  // Flutter Lifecycle
  'avoid_context_in_initstate_dispose',
  'avoid_inherited_widget_in_initstate',
  'avoid_build_context_in_providers',
  'avoid_unsafe_setstate',
  'use_setstate_synchronously',
  'avoid_recursive_widget_calls',
  'require_mounted_check',
  'avoid_global_key_in_build',
  'pass_existing_future_to_future_builder',
  'pass_existing_stream_to_stream_builder',
  'avoid_duplicate_widget_keys',
  'avoid_mounted_in_setstate',

  // Security
  'avoid_hardcoded_credentials',
  'avoid_logging_sensitive_data',
  'avoid_eval_like_patterns',
  'avoid_weak_cryptographic_algorithms',

  // Null Safety
  'avoid_null_assertion',
  'avoid_unsafe_collection_methods',
  'avoid_unsafe_reduce',
  'avoid_late_final_reassignment',

  // Async
  'avoid_throw_in_finally',
  'require_future_error_handling',

  // Collections
  'avoid_duplicate_map_keys',
  'avoid_isar_enum_field',

  // Architecture
  'avoid_circular_dependencies',

  // Resource Management
  'require_native_resource_cleanup',
  'require_file_close_in_finally',
  'require_database_close',
  'require_websocket_close',

  // Error Handling
  'avoid_swallowing_exceptions',
  'avoid_losing_stack_trace',
  'no_empty_block',
};

/// Recommended tier rules - Essential + common mistakes, performance basics.
const Set<String> recommendedOnlyRules = <String>{
  // Memory Management Best Practices
  'nullify_after_dispose',

  // Performance
  'avoid_expensive_build',
  'prefer_const_child_widgets',
  'avoid_listview_without_item_extent',
  'avoid_shrink_wrap_in_lists',
  'avoid_mediaquery_in_build',
  'prefer_dedicated_media_query_method',
  'avoid_singlechildscrollview_with_column',
  'avoid_stateful_widget_in_list',
  'prefer_cached_network_image',
  'avoid_controller_in_build',
  'avoid_setstate_in_build',
  'avoid_regex_in_loop',
  'prefer_const_string_list',
  'prefer_const_widgets_in_lists',

  // Accessibility
  'require_semantics_label',
  'avoid_icon_buttons_without_tooltip',
  'avoid_image_buttons_without_tooltip',
  'avoid_gesture_only_interactions',
  'avoid_color_only_indicators',
  'avoid_small_touch_targets',

  // State Management
  'require_notify_listeners',
  'avoid_bloc_event_in_constructor',

  // Error Handling
  'avoid_generic_exceptions',
  'avoid_catching_generic_exception',

  // Flutter Widgets
  'avoid_deeply_nested_widgets',
  'avoid_single_child_column_row',
  'avoid_form_without_key',
  'avoid_uncontrolled_text_field',
  'avoid_text_scale_factor',
  'prefer_using_list_view',
  'avoid_scaffold_messenger_after_await',
  'avoid_empty_setstate',
  'avoid_unnecessary_setstate',
  'avoid_stateless_widget_initialized_fields',
  'avoid_state_constructors',

  // Async
  'avoid_async_call_in_sync_function',
  'avoid_redundant_async',
  'avoid_future_tostring',
  'prefer_return_await',
  'avoid_future_ignore',
  'avoid_stream_tostring',

  // Code Quality
  'avoid_self_assignment',
  'avoid_self_compare',
  'avoid_assignments_as_conditions',
  'avoid_equal_expressions',
  'no_equal_then_else',
  'avoid_unnecessary_conditionals',
  'avoid_constant_conditions',
  'avoid_conditions_with_boolean_literals',
  'no_empty_string',
  'avoid_misnamed_padding',

  // Collections
  'avoid_map_keys_contains',
  'avoid_collection_equality_checks',
  'avoid_missing_enum_constant_in_map',
  'avoid_enum_values_by_index',
  'prefer_contains',
  'prefer_first',
  'prefer_last',

  // Testing
  'require_test_assertions',
  'avoid_real_network_calls_in_tests',
  'avoid_hardcoded_test_delays',
  'missing_test_assertion',
  'avoid_duplicate_test_assertions',

  // API & Network
  'require_http_status_check',
  'require_api_timeout',
  'avoid_hardcoded_api_urls',

  // Documentation
  'require_deprecation_message',

  // Type Safety
  'avoid_unsafe_cast',
  'require_safe_json_parsing',
  'require_null_safe_extensions',
  'avoid_unrelated_type_assertions',
  'avoid_unnecessary_type_assertions',
  'avoid_unnecessary_type_casts',

  // Naming & Style
  'prefer_boolean_prefixes',
  'avoid_getter_prefix',
};

/// Professional tier rules - Recommended + architecture, testing, maintainability.
const Set<String> professionalOnlyRules = <String>{
  // Architecture
  'avoid_direct_data_access_in_ui',
  'avoid_business_logic_in_ui',
  'avoid_god_class',
  'avoid_ui_in_domain_layer',
  'avoid_cross_feature_dependencies',

  // Security
  'require_certificate_pinning',
  'require_secure_storage',
  'require_input_sanitization',
  'avoid_hardcoded_asset_paths',
  'avoid_print_in_production',
  'avoid_webview_javascript_enabled',
  'require_biometric_fallback',

  // Accessibility
  'avoid_merged_semantics_hiding_info',
  'require_exclude_semantics_justification',
  'require_live_region',
  'require_heading_semantics',

  // State Management
  'require_update_should_notify',
  'avoid_watch_in_callbacks',
  'avoid_stateful_without_state',
  'avoid_global_riverpod_providers',

  // Error Handling
  'require_error_context',
  'prefer_result_pattern',
  'require_async_error_documentation',
  'require_error_boundary',

  // Performance
  'require_keys_in_animated_lists',
  'avoid_synchronous_file_io',
  'prefer_compute_for_heavy_work',
  'avoid_object_creation_in_hot_loops',
  'prefer_cached_getter',
  'require_item_extent_for_large_lists',
  'require_image_cache_dimensions',
  'prefer_image_precache',
  'avoid_excessive_widget_depth',
  'prefer_sliver_list_delegate',
  'avoid_layout_builder_misuse',
  'avoid_repaint_boundary_misuse',
  'avoid_gesture_detector_in_scrollview',
  'prefer_opacity_widget',

  // Testing
  'avoid_vague_test_descriptions',
  'require_pump_after_interaction',
  'avoid_production_config_in_tests',
  'avoid_empty_test_groups',
  'prefer_correct_test_file_name',
  'avoid_top_level_members_in_tests',
  'require_test_setup_teardown',
  'format_test_name',
  'prefer_unique_test_names',
  'prefer_test_structure',
  'prefer_test_matchers',

  // Documentation
  'require_public_api_documentation',
  'avoid_misleading_documentation',
  'require_complex_logic_comments',
  'require_parameter_documentation',
  'require_return_documentation',
  'require_exception_documentation',
  'require_example_in_documentation',

  // Dependency Injection
  'avoid_service_locator_in_widgets',
  'avoid_too_many_dependencies',
  'avoid_circular_di_dependencies',
  'avoid_internal_dependency_creation',
  'prefer_abstract_dependencies',
  'avoid_singleton_for_scoped_dependencies',
  'prefer_null_object_pattern',
  'require_typed_di_registration',

  // Memory Management
  'require_image_disposal',
  'require_cache_eviction_policy',
  'avoid_expando_circular_references',
  'avoid_large_objects_in_state',
  'avoid_capturing_this_in_callbacks',
  'prefer_weak_references_for_cache',
  'avoid_large_isolate_communication',

  // Flutter Widgets
  'avoid_flexible_outside_flex',
  'proper_super_calls',
  'avoid_unremovable_callbacks_in_listeners',
  'avoid_unnecessary_stateful_widgets',
  'check_for_equals_in_render_object_setters',
  'consistent_update_render_object',
  'avoid_unnecessary_overrides_in_state',
  'prefer_semantic_widget_names',
  'prefer_widget_state_mixin',
  'prefer_split_widget_const',
  'prefer_safe_area_consumer',
  'avoid_navigator_push_without_route_name',
  'prefer_scaffold_messenger_maybeof',
  'avoid_wrapping_in_padding',
  'avoid_unrestricted_text_field_length',
  'avoid_expanded_as_spacer',
  'avoid_unnecessary_gesture_detector',

  // Async
  'avoid_nested_futures',
  'avoid_nested_streams_and_futures',
  'prefer_correct_future_return_type',
  'prefer_correct_stream_return_type',
  'prefer_unwrapping_future_or',
  'prefer_specifying_future_value_type',
  'prefer_expect_later',
  'prefer_assigning_await_expressions',
  'avoid_unnecessary_futures',

  // Code Quality
  'avoid_long_functions',
  'avoid_long_parameter_list',
  'avoid_shadowing',
  'avoid_generics_shadowing',
  'avoid_similar_names',
  'avoid_unused_parameters',
  'avoid_duplicate_cascades',
  'avoid_complex_conditions',
  'prefer_early_return',
  'avoid_recursive_calls',
  'avoid_recursive_tostring',
  'avoid_missed_calls',
  'avoid_passing_self_as_argument',

  // Internationalization
  'avoid_hardcoded_strings_in_ui',
  'require_locale_aware_formatting',
  'avoid_hardcoded_locale',
  'avoid_string_concatenation_in_ui',
  'require_directional_widgets',
  'require_plural_handling',
  'avoid_text_in_images',
  'avoid_hardcoded_app_name',

  // API & Network
  'require_retry_logic',
  'require_typed_api_response',
  'require_api_error_mapping',
  'require_connectivity_check',

  // Resource Management
  'require_http_client_close',
  'require_platform_channel_cleanup',
  'require_isolate_kill',

  // Type Safety
  'prefer_constrained_generics',
  'require_covariant_documentation',
  'prefer_specific_numeric_types',
  'require_futureor_documentation',
};

/// Comprehensive tier rules - Professional + more code quality, style, and edge cases.
const Set<String> comprehensiveOnlyRules = <String>{
  // Architecture
  'avoid_singleton_pattern',
  'avoid_service_locator_overuse',

  // Flutter Widgets
  'avoid_border_all',
  'avoid_incorrect_image_opacity',
  'avoid_image_without_cache',
  'avoid_missing_image_alt',
  'prefer_const_border_radius',
  'prefer_correct_edge_insets_constructor',
  'prefer_text_rich',
  'prefer_define_hero_tag',
  'prefer_sliver_prefix',
  'prefer_widget_private_members',

  // Async
  'avoid_nullable_tostring',

  // Code Quality - Thorough
  'avoid_long_files',
  'avoid_local_functions',
  'avoid_declaring_call_method',
  'avoid_immediately_invoked_functions',
  'avoid_always_null_parameters',
  'avoid_mutating_parameters',
  'avoid_unused_callback_parameters',
  'function_always_returns_null',
  'function_always_returns_same_value',
  'avoid_unused_assignment',
  'avoid_unused_instances',
  'avoid_unused_after_null_check',
  'avoid_unused_generics',
  'avoid_unnecessary_local_variable',
  'avoid_unnecessary_reassignment',
  'avoid_complex_loop_conditions',
  'avoid_duplicate_switch_case_conditions',
  'avoid_wildcard_cases_with_enums',
  'avoid_wildcard_cases_with_sealed_classes',
  'no_equal_conditions',
  'no_equal_nested_conditions',
  'no_equal_switch_case',
  'no_equal_switch_expression_cases',
  'prefer_correct_switch_length',
  'prefer_specific_cases_first',
  'avoid_non_empty_constructor_bodies',
  'avoid_unnecessary_constructor',
  'avoid_unnecessary_super',
  'avoid_unnecessary_overrides',
  'avoid_assigning_to_static_field',
  'avoid_default_tostring',
  'avoid_incomplete_copy_with',
  'avoid_duplicate_mixins',
  'avoid_contradictory_expressions',

  // Control Flow
  'avoid_constant_assert_conditions',
  'avoid_constant_switches',
  'avoid_inverted_boolean_checks',
  'avoid_negated_conditions',
  'avoid_negations_in_equality_checks',
  'avoid_unnecessary_negations',
  'avoid_collapsible_if',
  'avoid_if_with_many_branches',
  'avoid_nested_switch_expressions',
  'avoid_nested_switches',
  'avoid_nested_try',
  'avoid_redundant_else',
  'avoid_unconditional_break',
  'avoid_continue',
  'avoid_unnecessary_continue',

  // Naming
  'prefer_correct_identifier_length',
  'prefer_correct_type_name',
  'prefer_correct_error_name',
  'prefer_correct_setter_parameter_name',
  'prefer_correct_callback_field_name',
  'prefer_correct_handler_name',
  'prefer_prefixed_global_constants',
  'prefer_trailing_underscore_for_unused',
  'match_getter_setter_field_names',

  // Records & Patterns
  'avoid_one_field_records',
  'avoid_long_records',
  'avoid_nested_records',
  'avoid_mixing_named_and_positional_fields',
  'avoid_function_type_in_records',
  'avoid_bottom_type_in_records',
  'avoid_extensions_on_records',
  'avoid_positional_record_field_access',
  'avoid_redundant_positional_field_name',
  'avoid_bottom_type_in_patterns',
  'avoid_duplicate_patterns',
  'avoid_explicit_pattern_field_name',
  'avoid_keywords_in_wildcard_pattern',
  'avoid_unnecessary_patterns',
  'avoid_single_field_destructuring',
  'avoid_nested_shorthands',
  'prefer_wildcard_pattern',
  'prefer_simpler_patterns_null_check',
  'move_records_to_typedefs',
  'match_positional_field_names_on_assignment',
  'use_existing_destructuring',
  'record_fields_ordering',
  'pattern_fields_ordering',

  // Formatting
  'format_comment',
  'prefer_commenting_analyzer_ignores',
  'prefer_commenting_future_delayed',
  'prefer_trailing_comma',
  'unnecessary_trailing_comma',
  'newline_before_case',
  'newline_before_method',
  'newline_before_constructor',

  // Imports
  'avoid_barrel_files',
  'avoid_double_slash_imports',
  'avoid_duplicate_exports',
  'avoid_duplicate_named_imports',
  'max_imports',
  'prefer_named_imports',

  // Collections
  'avoid_duplicate_collection_elements',
  'avoid_accessing_collections_by_constant_index',
  'avoid_slow_collection_methods',
  'prefer_add_all',
  'prefer_any_or_every',
  'prefer_for_in',
  'prefer_iterable_of',
  'prefer_set_for_lookup',
  'map_keys_ordering',
  'avoid_unnecessary_collections',

  // Exception
  'avoid_only_rethrow',
  'avoid_throw_in_catch_block',
  'avoid_throw_objects_without_tostring',
  'avoid_identical_exception_handling_blocks',
  'avoid_missing_completer_stack_trace',
  'avoid_non_final_exception_class_fields',
  'prefer_public_exception_classes',

  // Strings & Numbers
  'avoid_adjacent_strings',
  'avoid_non_ascii_symbols',
  'avoid_substring',
  'avoid_incorrect_uri',
  'no_magic_string',
  'avoid_complex_arithmetic_expressions',
  'avoid_bitwise_operators_with_booleans',
  'avoid_inconsistent_digit_separators',
  'avoid_unnecessary_digit_separators',
  'prefer_digit_separators',
  'prefer_addition_subtraction_assignments',
  'prefer_compound_assignment_operators',

  // Expressions
  'avoid_excessive_expressions',
  'avoid_cascade_after_if_null',
  'prefer_parentheses_with_if_null',
  'prefer_null_aware_spread',
  'prefer_null_aware_elements',

  // Unnecessary Code
  'avoid_unnecessary_block',
  'avoid_unnecessary_call',
  'avoid_unnecessary_extends',
  'avoid_unnecessary_getter',
  'avoid_unnecessary_statements',
  'avoid_unnecessary_length_check',
  'avoid_referencing_discarded_variables',
  'avoid_empty_spread',
  'avoid_duplicate_constant_values',
  'avoid_duplicate_initializers',
  'missing_use_result_annotation',

  // Variables
  'avoid_global_state',
  'avoid_multi_assignment',
  'avoid_nested_assignments',
  'move_variable_closer_to_usage',
  'move_variable_outside_iteration',
  'use_existing_variable',
  'prefer_type_over_var',

  // Equality
  'no_equal_arguments',
  'avoid_unnecessary_compare_to',
  'prefer_overriding_parent_equality',

  // Testing
  'prefer_visible_for_testing_on_members',

  // Pragmas
  'avoid_redundant_pragma_inline',
  'avoid_unknown_pragma',
  'prefer_both_inlining_annotations',

  // Advanced Rules
  'no_object_declaration',
  'avoid_casting_to_extension_type',
  'avoid_collection_methods_with_unrelated_types',
  'avoid_nullable_interpolation',
  'avoid_nullable_parameters_with_default_values',
  'avoid_unnecessary_nullable_fields',
  'avoid_unnecessary_nullable_parameters',
  'avoid_unnecessary_nullable_return_type',
  'avoid_hardcoded_colors',
  'avoid_debug_print',
  'avoid_unguarded_debug',
  'match_lib_folder_structure',
  'prefer_utc_datetimes',
};

/// Insanity tier rules - Everything including noisy/opinionated rules.
const Set<String> insanityOnlyRules = <String>{
  // Noisy but valuable
  'avoid_commented_out_code',
  'avoid_dynamic',
  'avoid_late_keyword',
  'avoid_nested_conditional_expressions',
  'avoid_passing_async_when_sync_expected',
  'binary_expression_operand_order',
  'double_literal_format',
  'member_ordering',
  'newline_before_return',
  'no_magic_number',
  'prefer_async_await',
  'prefer_conditional_expressions',
  'prefer_match_file_name',
  'prefer_moving_to_variable',
  'prefer_static_class',
  'avoid_returning_widgets',
  'prefer_extracting_callbacks',
  'prefer_single_widget_per_file',

  // Style Preferences
  'prefer_getter_over_method',
  'prefer_static_method',
  'prefer_named_parameters',
  'prefer_named_boolean_parameters',
  'prefer_explicit_function_type',
  'prefer_explicit_parameter_names',
  'prefer_typedef_for_callbacks',
  'prefer_extracting_function_callbacks',
  'avoid_returning_cascades',
  'avoid_returning_void',
  'prefer_returning_shorthands',
  'avoid_unnecessary_return',
  'prefer_immediate_return',
  'prefer_declaring_const_constructor',
  'prefer_abstract_final_static_class',
  'match_class_name_pattern',
  'match_base_class_default_value',
  'parameters_ordering',

  // Advanced Patterns
  'prefer_enhanced_enums',
  'prefer_enums_by_name',
  'avoid_unnecessary_enum_prefix',
  'avoid_unnecessary_enum_arguments',
  'prefer_shorthands_with_enums',
  'prefer_named_extensions',
  'avoid_nested_extension_types',
  'avoid_implicitly_nullable_extension_types',
  'prefer_private_extension_type_field',
  'avoid_shadowed_extension_methods',

  // Advanced Code Quality
  'avoid_unassigned_fields',
  'avoid_unassigned_late_fields',
  'avoid_unnecessary_late_fields',
  'avoid_unnecessary_local_late',
  'prefer_returning_condition',
  'prefer_returning_conditionals',
  'prefer_switch_expression',
  'prefer_switch_with_enums',
  'prefer_switch_with_sealed_classes',
  'prefer_pushing_conditional_expressions',
  'avoid_unnecessary_if',
  'pass_correct_accepted_type',
  'pass_optional_argument',
  'prefer_shorthands_with_constructors',
  'prefer_shorthands_with_static_fields',
  'avoid_inferrable_type_arguments',
  'avoid_passing_default_values',
  'prefer_single_declaration_per_file',
  'prefer_bytes_builder',

  // Testing
  'tag_name',
};

/// Get all rules for a specific tier.
Set<String> getRulesForTier(String tier) {
  switch (tier.toLowerCase()) {
    case 'essential':
      return essentialRules;
    case 'recommended':
      return <String>{...essentialRules, ...recommendedOnlyRules};
    case 'professional':
      return <String>{
        ...essentialRules,
        ...recommendedOnlyRules,
        ...professionalOnlyRules,
      };
    case 'comprehensive':
      return <String>{
        ...essentialRules,
        ...recommendedOnlyRules,
        ...professionalOnlyRules,
        ...comprehensiveOnlyRules,
      };
    case 'insanity':
    case 'all':
      return <String>{
        ...essentialRules,
        ...recommendedOnlyRules,
        ...professionalOnlyRules,
        ...comprehensiveOnlyRules,
        ...insanityOnlyRules,
      };
    default:
      // Default to essential if unknown tier
      return essentialRules;
  }
}
