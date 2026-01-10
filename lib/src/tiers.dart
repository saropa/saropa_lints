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
  'require_scroll_controller_dispose',
  'require_focus_node_dispose',
  'require_text_editing_controller_dispose',
  'require_page_controller_dispose',
  'require_bloc_close',
  'require_media_player_dispose',
  'require_tab_controller_dispose',
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
  'avoid_sensitive_data_in_logs',
  'avoid_eval_like_patterns',
  'avoid_weak_cryptographic_algorithms',
  'avoid_token_in_url',
  'avoid_clipboard_sensitive',
  'avoid_storing_passwords',
  'avoid_dynamic_sql',
  'avoid_hardcoded_encryption_keys',
  'prefer_secure_random_for_crypto',
  'avoid_deprecated_crypto_algorithms',
  'require_unique_iv_per_encryption',

  // Null Safety
  'avoid_null_assertion',
  'avoid_unsafe_collection_methods',
  'avoid_unsafe_where_methods',
  'avoid_unsafe_reduce',
  'avoid_late_final_reassignment',

  // State Management - Critical (Batch 10)
  'avoid_bloc_event_mutation', // Immutability is critical
  'require_initial_state', // Runtime crash without it
  'avoid_instantiating_in_bloc_value_provider', // Memory leak
  'avoid_existing_instances_in_bloc_provider', // Unexpected closure
  'avoid_instantiating_in_value_provider', // Memory leak (Provider package)
  'dispose_providers', // Resource cleanup
  'proper_getx_super_calls', // Broken lifecycle
  'always_remove_getx_listener', // Memory leak
  'avoid_hooks_outside_build', // Runtime error
  'avoid_conditional_hooks', // Runtime error

  // Forms - Critical (Batch 12)
  'require_form_key', // Forms won't work without it
  'avoid_clearing_form_on_error', // Data loss

  // Async
  'avoid_throw_in_finally',
  'require_future_error_handling',
  'avoid_uncaught_future_errors',

  // Collections
  'avoid_duplicate_map_keys',
  'avoid_isar_enum_field',

  // Equatable (Essential - missing fields cause equality bugs)
  'list_all_equatable_fields',

  // Architecture
  'avoid_circular_dependencies',

  // GetIt/DI (Essential - wrong usage)
  'avoid_functions_in_register_singleton',

  // Resource Management
  'require_native_resource_cleanup',
  'require_file_close_in_finally',
  'require_database_close',
  'require_websocket_close',

  // Error Handling
  'avoid_swallowing_exceptions',
  'avoid_losing_stack_trace',
  'no_empty_block',

  // Collection/Loop Safety (Phase 2)
  'avoid_unreachable_for_loop',

  // GetX (Phase 2 - memory leaks)
  'avoid_getx_rx_inside_build',
  'avoid_mutable_rx_variables',

  // Remaining ROADMAP_NEXT - resource cleanup
  'dispose_provided_instances',
  'dispose_getx_fields',

  // Widget Structure
  'avoid_nested_scaffolds',
  'avoid_multiple_material_apps',

  // Build Method Anti-patterns (Critical)
  'avoid_dialog_in_build',
  'require_tab_controller_length_sync',

  // Type Safety (Critical - throws runtime exceptions)
  'prefer_try_parse_for_dynamic_data',
  'avoid_double_for_money',

  // Animation (Essential - prevent crashes)
  'require_vsync_mixin',
  'require_animation_controller_dispose',

  // Resource Management (Essential - prevent hardware lock)
  'require_camera_dispose',

  // Accessibility (Essential - critical errors)
  'avoid_hidden_interactive',
  'require_error_identification',
  'require_minimum_contrast',

  // Navigation (Essential - prevent crashes)
  'require_unknown_route_handler',
  'avoid_context_after_navigation',
  'require_route_guards',
  'avoid_circular_redirects',

  // Riverpod (Essential - prevent crashes)
  'avoid_ref_in_dispose',
  'require_provider_scope',
  'avoid_circular_provider_deps',
  'require_error_handling_in_async',
  'avoid_ref_read_inside_build',
  'avoid_ref_watch_outside_build',
  'avoid_ref_inside_state_dispose',
  'use_ref_read_synchronously',
  'use_ref_and_state_synchronously',
  'avoid_assigning_notifiers',

  // Bloc (Essential - prevent crashes)
  'check_is_not_closed_after_async_gap',
  'avoid_duplicate_bloc_event_handlers',

  // GetX (Essential - prevent memory leaks)
  'require_getx_controller_dispose',

  // Build Performance (Essential - prevent memory leaks)
  'avoid_scroll_listener_in_build',

  // Security (Essential - prevent data leaks)
  'avoid_auth_in_query_params',
  'require_deep_link_validation',

  // Firebase (Essential - prevent crashes)
  'require_firebase_init_before_use',
  'incorrect_firebase_event_name',
  'incorrect_firebase_parameter_name',

  // Notification (Essential - required for Android 8+)
  'require_notification_channel_android',

  // Testing (Essential - prevent flaky tests)
  'avoid_datetime_now_in_tests',
  'missing_test_assertion',
  'avoid_async_callback_in_fake_async',

  // QR/Camera (Essential - app store compliance)
  'require_qr_permission_check',

  // Lifecycle (Essential - battery/stability)
  'require_lifecycle_observer',

  // Disposal (roadmap_up_next - memory leak)
  'require_stream_subscription_cancel',

  // Async (roadmap_up_next - runtime crash)
  'avoid_dialog_context_after_async',
};

/// Recommended tier rules - Essential + common mistakes, performance basics.
const Set<String> recommendedOnlyRules = <String>{
  // Memory Management Best Practices
  'nullify_after_dispose',
  'require_auto_dispose',

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
  'prefer_value_listenable_builder',

  // Build Method Anti-patterns (Performance/UX)
  'avoid_gradient_in_build',
  'avoid_snackbar_in_build',
  'avoid_analytics_in_build',
  'avoid_json_encode_in_build',
  'avoid_canvas_operations_in_build',

  // Scroll and List Performance
  'avoid_shrinkwrap_in_scrollview',
  'avoid_nested_scrollables_conflict',
  'avoid_listview_children_for_large_lists',
  'avoid_refresh_without_await',
  'avoid_multiple_autofocus',

  // JSON/DateTime Error Handling
  'require_json_decode_try_catch',
  'avoid_datetime_parse_unvalidated',
  'require_websocket_error_handling',

  // Accessibility
  'require_semantics_label',
  'avoid_icon_buttons_without_tooltip',
  'avoid_image_buttons_without_tooltip',
  'avoid_gesture_only_interactions',
  'avoid_color_only_indicators',
  'avoid_small_touch_targets',
  'avoid_text_scale_factor_ignore',
  'require_image_semantics',
  'prefer_scalable_text',
  'require_safe_area_handling',

  // Theming
  'prefer_system_theme_default',

  // Widget optimization
  'prefer_transform_over_container',
  'prefer_action_button_tooltip',

  // State Management
  'require_notify_listeners',
  'avoid_bloc_event_in_constructor',
  'avoid_provider_recreate',
  'avoid_provider_in_widget',

  // Animation
  'avoid_animation_in_build',
  'require_hero_tag_uniqueness',

  // Security
  'prefer_secure_random',
  'require_secure_keyboard',
  'require_auth_check',
  'avoid_jwt_decode_client',
  'require_logout_cleanup',

  // Firebase/Database/Storage
  'avoid_firestore_unbounded_query',
  'avoid_database_in_build',
  'avoid_prefs_for_large_data',

  // Error Handling
  'avoid_generic_exceptions',
  'avoid_catching_generic_exception',

  // Flutter Widgets
  'avoid_deeply_nested_widgets',
  'avoid_single_child_column_row',
  'avoid_nested_scrollables',
  'require_text_overflow_handling',
  'require_image_error_builder',
  'avoid_form_without_key',
  'avoid_uncontrolled_text_field',
  'avoid_text_scale_factor',
  'prefer_using_list_view',
  'avoid_scaffold_messenger_after_await',
  'avoid_empty_setstate',
  'avoid_unnecessary_setstate',
  'avoid_stateless_widget_initialized_fields',
  'avoid_state_constructors',
  'avoid_empty_text_widgets',
  'prefer_sized_box_for_whitespace',
  'prefer_sized_box_square',
  'prefer_center_over_align',
  'prefer_align_over_container',
  'prefer_padding_over_container',
  'prefer_constrained_box_over_container',
  'prefer_multi_bloc_provider',
  'prefer_correct_bloc_provider',
  'prefer_multi_provider',
  'avoid_unnecessary_hook_widgets',
  'prefer_inkwell_over_gesture',
  'prefer_listview_builder',
  'avoid_opacity_animation',
  'prefer_spacing_over_sizedbox',
  'avoid_material2_fallback',
  'avoid_navigator_push_unnamed',

  // Performance
  'avoid_string_concatenation_loop',
  'avoid_large_list_copy',

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
  'prefer_where_or_null',

  // Testing
  'require_test_assertions',
  'avoid_real_network_calls_in_tests',
  'avoid_hardcoded_test_delays',
  'missing_test_assertion',
  'avoid_duplicate_test_assertions',
  'avoid_test_coupling',
  'require_test_isolation',
  'avoid_real_dependencies_in_tests',
  'require_error_case_tests',

  // State Management (Batch 10)
  'prefer_copy_with_for_state',
  'avoid_bloc_listen_in_build',

  // Performance (Batch 11)
  'require_build_context_scope', // Can cause crashes after await
  'avoid_memory_intensive_operations',
  'avoid_closure_memory_leak',
  'require_dispose_pattern',

  // Forms (Batch 12)
  'avoid_validation_in_build',

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
  'prefer_wildcard_for_unused_param',

  // Security (Batch 14)
  'avoid_auth_state_in_prefs',

  // Accessibility (Batch 14)
  'require_button_semantics',
  'avoid_hover_only',

  // State Management (Batch 14)
  'prefer_ref_watch_over_read',
  'avoid_change_notifier_in_widget',
  'require_provider_dispose',

  // Notification (Batch 14)
  'avoid_notification_payload_sensitive',

  // GetX (Batch 17)
  'avoid_obs_outside_controller',

  // Accessibility (Plan Group C)
  'require_avatar_alt_text',
  'require_badge_semantics',
  'require_badge_count_limit',

  // Image & Media (Plan Group A)
  'require_avatar_fallback',
  'prefer_video_loading_placeholder',

  // Dialog & Snackbar (Plan Group D)
  'require_snackbar_duration',
  'require_dialog_barrier_dismissible',

  // Form & Input (Plan Group E)
  'require_keyboard_action_type',
  'require_keyboard_dismiss_on_scroll',

  // Duration & DateTime (Plan Group F)
  'prefer_duration_constants',

  // UI/UX (Plan Groups G, J, K)
  'require_responsive_breakpoints',
  'require_currency_formatting_locale',
  'require_graphql_operation_names',

  // Bluetooth & Hardware (Plan Group H)
  'avoid_bluetooth_scan_without_timeout',
  'require_bluetooth_state_check',
  'require_ble_disconnect_handling',

  // File & Error Handling (Plan Group G)
  'require_file_exists_check',
  'require_pdf_error_handling',
  'require_graphql_error_handling',

  // QR Scanner (Plan Group I)
  'require_qr_scan_feedback',

  // Phase 2 Rules - Collection/Loop
  'prefer_correct_for_loop_increment',

  // Phase 2 Rules - Widget Optimization
  'prefer_single_setstate',
  'avoid_empty_build_when',

  // Phase 2 Rules - Riverpod
  'avoid_unnecessary_consumer_widgets',
  'avoid_nullable_async_value_pattern',

  // Phase 2 Rules - Flame Engine
  'avoid_creating_vector_in_update',
  'avoid_redundant_async_on_load',

  // Image rules (roadmap_up_next)
  'require_image_loading_placeholder',

  // Async rules (roadmap_up_next)
  'require_location_timeout',

  // Firebase/Maps rules (roadmap_up_next - aliases)
  'avoid_firestore_in_widget_build',

  // Accessibility rules (roadmap_up_next)
  'require_image_description',
  'avoid_motion_without_reduce',

  // Navigation rules (roadmap_up_next)
  'require_refresh_indicator_on_lists',
};

/// Professional tier rules - Recommended + architecture, testing, maintainability.
/// Includes stricter naming conventions for API parameters.
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
  'require_token_refresh',

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
  'prefer_consumer_widget',
  'avoid_provider_of_in_build',
  'avoid_get_find_in_build',
  'prefer_cubit_for_simple',
  'require_bloc_observer',
  'prefer_select_for_partial',
  'prefer_family_for_params',

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
  'avoid_layout_passes',
  'prefer_typed_data',
  'avoid_unnecessary_to_list',
  'avoid_global_key_misuse',
  'require_repaint_boundary',
  'avoid_unconstrained_images',

  // Forms/UX
  'prefer_autovalidate_on_interaction',
  'require_keyboard_type',
  'require_text_overflow_in_row',
  'require_error_message_context',

  // Equatable (Professional - cleaner patterns)
  'extend_equatable',
  'prefer_equatable_mixin',

  // Types (Professional - cleaner patterns)
  'prefer_void_callback',

  // Testing (Professional - better test patterns)
  'prefer_symbol_over_key',

  // Riverpod (Professional - cleaner patterns)
  'avoid_notifier_constructors',
  'prefer_immutable_provider_arguments',

  // Provider (Professional - type safety)
  'prefer_nullable_provider_types',

  // Bloc (Professional - cleaner patterns)
  'prefer_immutable_bloc_events',
  'prefer_immutable_bloc_state',
  'prefer_sealed_bloc_events',
  'prefer_sealed_bloc_state',

  // State Management (Batch 10)
  'require_error_state',
  'avoid_bloc_in_bloc',
  'prefer_sealed_events',

  // Performance (Batch 11)
  'prefer_const_widgets',
  'avoid_expensive_computation_in_build',
  'avoid_widget_creation_in_loop',
  'avoid_calling_of_in_build',
  'require_image_cache_management',
  'prefer_static_const_widgets',

  // Forms (Batch 12)
  'require_submit_button_state',
  'avoid_form_without_unfocus',
  'require_form_restoration',
  'require_form_field_controller',
  'avoid_form_in_alert_dialog',

  // Platform/Storage
  'require_prefs_key_constants',
  'avoid_secure_storage_on_web',

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
  'prefer_pump_and_settle',
  'require_test_groups',
  'require_scroll_tests',
  'require_text_input_tests',
  'prefer_single_assertion',
  'avoid_find_all',
  'require_integration_test_setup',

  // Flutter Widgets - Pointer handling
  'avoid_absorb_pointer_misuse',
  'avoid_brightness_check_for_theme',

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
  'avoid_getit_in_build',
  'require_getit_reset_in_tests',

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
  'require_image_dimensions',
  'require_placeholder_for_network',
  'prefer_text_theme',
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
  'prefer_overlay_portal',
  'prefer_carousel_view',
  'prefer_search_anchor',
  'prefer_tap_region_for_dismiss',

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
  'prefer_async_callback',

  // Code Quality
  'avoid_long_functions',
  'avoid_long_parameter_list',
  'avoid_shadowing',
  'avoid_generics_shadowing',
  'avoid_unmarked_public_class',
  'prefer_final_class',
  'prefer_interface_class',
  'prefer_base_class',
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
  'prefer_date_format',
  'prefer_intl_name',
  'prefer_providing_intl_description',
  'prefer_providing_intl_examples',

  // API & Network
  'require_retry_logic',
  'require_typed_api_response',
  'require_api_error_mapping',
  'require_connectivity_check',
  'require_offline_indicator',

  // Resource Management
  'require_http_client_close',
  'require_platform_channel_cleanup',
  'require_isolate_kill',
  'require_image_compression',
  'prefer_coarse_location_when_sufficient',

  // Animation (Professional - polish)
  'avoid_hardcoded_duration',
  'require_animation_curve',
  'prefer_implicit_animations',
  'require_staggered_animation_delays',

  // Navigation (Professional - consistency)
  'require_route_transition_consistency',
  'avoid_pop_without_result',
  'prefer_shell_route_for_persistent_ui',

  // Type Safety
  'prefer_constrained_generics',
  'require_covariant_documentation',
  'prefer_specific_numeric_types',
  'require_futureor_documentation',
  'prefer_explicit_type_arguments',

  // Naming & Style
  'prefer_boolean_prefixes_for_params',

  // Security (Batch 14)
  'prefer_encrypted_prefs',

  // Accessibility (Batch 14)
  'prefer_explicit_semantics',

  // Testing (Batch 14)
  'avoid_hardcoded_delays',

  // Resource Management (Batch 14)
  'avoid_image_picker_without_source',

  // Platform (Batch 14)
  'prefer_url_strategy_for_web',
  'require_window_size_constraints',

  // Gap Analysis Rules (Batch 15)
  'avoid_returning_widgets',
  'avoid_nullable_widget_methods',
  'avoid_duplicate_string_literals',
  'avoid_setstate_in_large_state_class',

  // State Management (Batch 17)
  'prefer_notifier_over_state',
  'require_bloc_transformer',
  'avoid_long_event_handlers',

  // Performance (Batch 17)
  'require_list_preallocate',
  'prefer_builder_for_conditional',
  'require_widget_key_strategy',

  // Image & Media (Plan Group A)
  'avoid_image_rebuild_on_scroll',

  // Dialog & Snackbar (Plan Group D)
  'require_dialog_result_handling',
  'avoid_snackbar_queue_buildup',

  // UI/UX (Plan Groups J, K)
  'prefer_cached_paint_objects',
  'require_custom_painter_shouldrepaint',
  'require_number_formatting_locale',
  'avoid_badge_without_meaning',
  'prefer_logger_over_print',
  'prefer_itemextent_when_known',
  'require_tab_state_preservation',

  // Hardware (Plan Group H)
  'require_audio_focus_handling',

  // QR Scanner (Plan Group I)
  'avoid_qr_scanner_always_active',

  // Image (Plan Group A)
  'prefer_image_size_constraints',

  // Phase 2 Rules - Widget Optimization
  'prefer_compute_over_isolate_run',
  'prefer_for_loop_in_children',
  'prefer_container',

  // Phase 2 Rules - Provider Advanced
  'prefer_immutable_selector_value',
  'prefer_provider_extensions',

  // Phase 2 Rules - Code Quality
  'prefer_typedefs_for_callbacks',
  'prefer_redirecting_superclass_constructor',

  // Phase 2 Rules - Bloc Naming
  'prefer_bloc_event_suffix',
  'prefer_bloc_state_suffix',

  // Phase 2 Rules - Hooks
  'prefer_use_prefix',

  // Firebase rules (roadmap_up_next)
  'prefer_firestore_batch_write',

  // Animation rules (roadmap_up_next)
  'require_animation_status_listener',

  // Platform rules (roadmap_up_next)
  'avoid_touch_only_gestures',

  // Test rules (roadmap_up_next)
  'require_test_cleanup',
  'require_accessibility_tests',
};

/// Comprehensive tier rules - Professional + more code quality, style, and edge cases.
const Set<String> comprehensiveOnlyRules = <String>{
  // Architecture
  'avoid_singleton_pattern',
  'avoid_service_locator_overuse',

  // Theming & Styling (Comprehensive - design consistency)
  'avoid_fixed_dimensions',
  'require_theme_color_from_scheme',
  'prefer_color_scheme_from_seed',
  'prefer_rich_text_for_complex',

  // Flutter Widgets
  'avoid_border_all',
  'avoid_fitted_box_for_text',
  'avoid_icon_size_override',
  'avoid_image_repeat',
  'avoid_incorrect_image_opacity',
  'avoid_image_without_cache',
  'avoid_missing_image_alt',
  'avoid_raw_keyboard_listener',
  'avoid_sized_box_expand',
  'prefer_const_border_radius',
  'prefer_correct_edge_insets_constructor',
  'prefer_define_hero_tag',
  'prefer_selectable_text',
  'prefer_sliver_prefix',
  'prefer_text_rich',
  'prefer_widget_private_members',
  'avoid_text_span_in_build',
  'require_overflow_box_rationale',
  'avoid_excessive_bottom_nav_items',

  // Code Quality - Feature Flags
  'avoid_hardcoded_feature_flags',

  // Media/Audio
  'avoid_autoplay_audio',

  // Network Performance
  'prefer_streaming_response',

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
  'prefer_when_guard_over_if',

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
  'prefer_pattern_destructuring',

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
  'avoid_duplicate_string_literals_pair', // Stricter version of professional rule
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

  // Naming & Style
  'prefer_boolean_prefixes_for_locals',

  // Platform (Batch 14 - opinionated)
  'prefer_cupertino_for_ios_feel',
  'prefer_keyboard_shortcuts',

};

/// Insanity tier rules - Everything including noisy/opinionated rules.
const Set<String> insanityOnlyRules = <String>{
  // Security - high false positive rates
  'avoid_generic_key_in_url',

  // Noisy but valuable
  'prefer_blank_line_before_case',
  'prefer_blank_line_before_method',
  'prefer_blank_line_before_constructor',
  'enum_constants_ordering',
  'avoid_commented_out_code',
  'avoid_dynamic',
  'avoid_late_keyword',
  'avoid_nested_conditional_expressions',
  'avoid_passing_async_when_sync_expected',
  'binary_expression_operand_order',
  'double_literal_format',
  'member_ordering',
  'prefer_blank_line_before_return',
  'no_magic_number',
  'prefer_async_await',
  'prefer_conditional_expressions',
  'prefer_match_file_name',
  'prefer_moving_to_variable',
  'prefer_static_class',
  'prefer_extracting_callbacks',
  'prefer_single_widget_per_file',

  // Style Preferences
  'prefer_getter_over_method',
  'prefer_static_method',
  'prefer_named_parameters',
  'prefer_named_boolean_parameters',
  'avoid_font_weight_as_number',
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
