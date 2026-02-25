/// Tier-based rule configuration for saropa_lints.
/// See README.md "The 5 Tiers" section for tier definitions and philosophy.
library;

export 'tiers.dart' show getRulesForTier;

// cspell:ignore require_sqflite_whereargs getit futureor shouldrepaint itemextent singlechildscrollview

/// Stylistic tier rules - formatting, ordering, naming conventions.
/// Orthogonal to correctness - code can be correct while violating these.
///
/// NOTE: Conflicting pairs (e.g., prefer_single_quotes vs prefer_double_quotes)
/// are intentionally excluded. Users must explicitly enable one of the pair.
/// See README_STYLISTIC.md for all available rules including conflicting pairs.
const Set<String> stylisticRules = <String>{
  // === Debug/Test utility ===
  'prefer_fail_test_case', // Test hook - always fails
  // === Ordering & Sorting ===
  'prefer_member_ordering',
  'prefer_arguments_ordering',
  'prefer_sorted_parameters',
  'prefer_sorted_pattern_fields',
  'prefer_sorted_record_fields',
  'binary_expression_operand_order', // Moved from professional (opinionated)
  'enforce_parameters_ordering', // Moved from professional (opinionated)
  'enum_constants_ordering', // Moved from professional (opinionated)
  'map_keys_ordering', // Moved from professional (opinionated)
  // === Naming conventions ===
  'prefer_boolean_prefixes',
  'prefer_no_getter_prefix',
  'prefer_kebab_tag_name',
  'prefer_capitalized_comment_start',
  'prefer_descriptive_bool_names',
  'prefer_snake_case_files',
  'prefer_camel_case_method_names',
  'prefer_exception_suffix',
  'prefer_error_suffix',
  'prefer_boolean_prefixes_for_params', // Moved from professional (opinionated)
  'prefer_boolean_prefixes_for_locals', // Moved from professional (opinionated)
  'prefer_trailing_underscore_for_unused', // Moved from professional (opinionated)
  'prefer_sliver_prefix', // Moved from professional (opinionated)
  'prefer_correct_callback_field_name', // Moved from professional (opinionated)
  'prefer_correct_handler_name', // Moved from professional (opinionated)
  'prefer_correct_setter_parameter_name', // Moved from professional (opinionated)
  'prefer_bloc_event_suffix', // Moved from comprehensive (opinionated)
  'prefer_bloc_state_suffix', // Moved from comprehensive (opinionated)
  'prefer_use_prefix', // Moved from comprehensive (opinionated)
  // === Error handling style ===
  'prefer_catch_over_on',

  // === Code style preferences ===
  'prefer_no_continue_statement',
  'prefer_single_exit_point',
  'prefer_wildcard_for_unused_param',
  'prefer_rethrow_over_throw_e',
  'prefer_list_first', // Moved from recommended (opinionated)
  'prefer_list_last', // Moved from recommended (opinionated)
  'prefer_sized_box_square', // Moved from recommended (opinionated)
  'prefer_center_over_align', // Moved from recommended (opinionated)
  'prefer_spacing_over_sizedbox', // Moved from recommended (opinionated)
  'no_boolean_literal_compare', // Moved from recommended (opinionated)
  'prefer_returning_conditional_expressions', // Moved from recommended (opinionated)
  'prefer_duration_constants', // Moved from recommended (opinionated)
  'prefer_immediate_return', // Moved from professional (opinionated)
  'prefer_for_in', // Moved from professional (opinionated)
  'prefer_getter_over_method', // Moved from professional (opinionated)
  'prefer_conditional_expressions', // Moved from professional (opinionated)
  'prefer_returning_condition', // Moved from professional (opinionated)
  'prefer_returning_conditionals', // Moved from professional (opinionated)
  'prefer_returning_shorthands', // Moved from professional (opinionated)
  'prefer_pushing_conditional_expressions', // Moved from professional (opinionated)
  'prefer_type_over_var', // Moved from professional (conflicts with prefer_var_over_explicit_type)
  // === Function & Parameter style ===
  'prefer_arrow_functions',
  'prefer_all_named_parameters',
  'prefer_inline_callbacks',
  'avoid_parameter_reassignment',

  // === Widget style ===
  'avoid_shrink_wrap_in_scroll',
  'prefer_one_widget_per_file',
  'prefer_widget_methods_over_classes',
  'prefer_borderradius_circular',
  'avoid_small_text',

  // === Class & Record style ===
  'prefer_class_over_record_return',
  'prefer_private_underscore_prefix',
  'prefer_explicit_this',

  // === Formatting ===
  'prefer_trailing_comma_always',
  'prefer_blank_line_before_case', // Moved from professional (opinionated)
  'prefer_blank_line_before_constructor', // Moved from professional (opinionated)
  'prefer_blank_line_before_method', // Moved from professional (opinionated)
  'prefer_blank_line_before_return', // Moved from professional (opinionated)
  'prefer_trailing_comma', // Moved from professional (opinionated)
  'unnecessary_trailing_comma', // Moved from professional (opinionated)
  'double_literal_format', // Moved from professional (opinionated)
  'format_comment_style', // Moved from pedantic (opinionated)
  // === Comments & Documentation ===
  'prefer_todo_format',
  'prefer_fixme_format',
  'prefer_sentence_case_comments',
  'prefer_period_after_doc',
  'prefer_doc_comments_over_regular',
  'prefer_no_commented_out_code', // Moved from pedantic (v4.2.0)
  // === Testing style ===
  'prefer_expect_over_assert_in_tests',
  // === Type argument style (conflicting, opt-in only) ===
  'prefer_inferred_type_arguments',
  'prefer_explicit_type_arguments',

  // === Import style (opinionated - opt-in only) ===
  'prefer_absolute_imports',
  'prefer_flat_imports',
  'prefer_grouped_imports',
  'prefer_named_imports',
  'prefer_relative_imports',
  'prefer_import_group_comments',

  // === Quote style (conflicting pair - opt-in only) ===
  'prefer_double_quotes',
  'prefer_single_quotes',

  // === Apostrophe style (conflicting pair - opt-in only) ===
  'prefer_doc_curly_apostrophe',
  'prefer_doc_straight_apostrophe',
  'prefer_straight_apostrophe',

  // === Member ordering (conflicting pairs - opt-in only) ===
  'prefer_static_members_first',
  'prefer_instance_members_first',
  'prefer_public_members_first',
  'prefer_private_members_first',

  // === Opinionated prefer_* rules (conflicting/stylistic - opt-in only) ===
  'prefer_addall_over_spread',
  'prefer_await_over_then',
  'prefer_blank_line_after_declarations',
  'prefer_blank_lines_between_members',
  'prefer_cascade_over_chained',
  'prefer_chained_over_cascade',
  'prefer_clip_r_superellipse',
  'prefer_clip_r_superellipse_clipper',
  'prefer_collection_if_over_ternary',
  'prefer_compact_class_members',
  'prefer_compact_declarations',
  'prefer_concatenation_over_interpolation',
  'prefer_concise_variable_names',
  'prefer_constructor_assertion',
  'prefer_constructor_body_assignment',
  'prefer_container_over_sizedbox',
  'prefer_curly_apostrophe',
  'prefer_default_enum_case',
  'prefer_descriptive_bool_names_strict',
  'prefer_descriptive_variable_names',
  'prefer_dot_shorthand',
  'prefer_dynamic_over_object',
  'prefer_edgeinsets_only',
  'prefer_edgeinsets_symmetric',
  'prefer_exhaustive_enums',
  'prefer_expanded_over_flexible',
  'prefer_explicit_boolean_comparison',
  'prefer_explicit_colors',
  'prefer_explicit_null_assignment',
  'prefer_explicit_types',
  'prefer_factory_for_validation',
  'prefer_fake_over_mock',
  'prefer_fields_before_methods',
  'prefer_flexible_over_expanded',
  'prefer_future_void_function_over_async_callback',
  'prefer_generic_exception',
  'prefer_given_when_then_comments',
  'prefer_grouped_by_purpose',
  'prefer_grouped_expectations',
  'prefer_guard_clauses',
  'prefer_if_null_over_ternary',
  'prefer_implicit_boolean_comparison',
  'prefer_initializing_formals',
  'prefer_interpolation_over_concatenation',
  'prefer_keys_with_lookup',
  'prefer_late_over_nullable',
  'prefer_lower_camel_case_constants',
  'prefer_map_entries_iteration',
  'prefer_material_theme_colors',
  'prefer_methods_before_fields',
  'prefer_no_blank_line_before_return',
  'prefer_no_blank_line_inside_blocks',
  'prefer_null_aware_assignment',
  'prefer_nullable_over_late',
  'prefer_object_over_dynamic',
  'prefer_on_over_catch',
  'prefer_positive_conditions',
  'prefer_positive_conditions_first',
  'prefer_required_before_optional',
  'prefer_richtext_over_text_rich',
  'prefer_screaming_case_constants',
  'prefer_self_documenting_tests',
  'prefer_single_blank_line_max',
  'prefer_single_expectation_per_test',
  'prefer_sizedbox_over_container',
  'prefer_specific_exceptions',
  'prefer_spread_over_addall',
  'prefer_super_parameters',
  'prefer_switch_statement',
  'prefer_sync_over_async_where_possible',
  'prefer_ternary_over_collection_if',
  'prefer_ternary_over_if_null',
  'prefer_test_data_builder',
  'prefer_test_name_descriptive',
  'prefer_test_name_should_when',
  'prefer_text_rich_over_richtext',
  'prefer_then_over_await',
  'prefer_var_over_explicit_type',
  'prefer_wheretype_over_where_is',

  // === Control flow & collection style (opinionated - opt-in only) ===
  'prefer_early_return',
  'prefer_mutable_collections',
  'prefer_record_over_equatable',
};

/// Stylistic rules that only apply to Flutter projects (widget-related).
///
/// Used by the interactive walkthrough to skip these rules for pure Dart
/// projects that have no Flutter dependency. These are a subset of
/// [stylisticRules] — not a separate tier.
const Set<String> flutterStylisticRules = <String>{
  'avoid_shrink_wrap_in_scroll',
  'avoid_small_text',
  'prefer_borderradius_circular',
  'prefer_center_over_align',
  'prefer_clip_r_superellipse',
  'prefer_clip_r_superellipse_clipper',
  'prefer_container_over_sizedbox',
  'prefer_edgeinsets_only',
  'prefer_edgeinsets_symmetric',
  'prefer_expanded_over_flexible',
  'prefer_explicit_colors',
  'prefer_flexible_over_expanded',
  'prefer_getter_over_method',
  'prefer_material_theme_colors',
  'prefer_one_widget_per_file',
  'prefer_richtext_over_text_rich',
  'prefer_sized_box_square',
  'prefer_sizedbox_over_container',
  'prefer_sliver_prefix',
  'prefer_spacing_over_sizedbox',
  'prefer_text_rich_over_richtext',
  'prefer_widget_methods_over_classes',
};

/// Essential tier rules - Critical rules that prevent crashes, data loss, and security holes.
/// A single violation causes real harm: app crashes, data exposed, resources never released.
const Set<String> essentialRules = <String>{
  // Memory Leaks - Controllers (dispose)
  'require_field_dispose',
  'require_animation_disposal',
  'avoid_undisposed_instances',
  'require_value_notifier_dispose',
  'require_focus_node_dispose',
  'require_page_controller_dispose',
  'require_media_player_dispose',
  // Memory Leaks - Timers & Subscriptions (cancel)
  'avoid_unassigned_stream_subscriptions',
  'require_stream_controller_dispose',
  'always_remove_listener',
  // Flutter Lifecycle - causes crashes
  'avoid_setstate_in_build', // Infinite loop/crash
  'avoid_inherited_widget_in_initstate',
  'avoid_recursive_widget_calls',
  'avoid_global_key_in_build',
  'pass_existing_future_to_future_builder',
  'pass_existing_stream_to_stream_builder',
  'avoid_duplicate_widget_keys',
  'avoid_mounted_in_setstate',
  'avoid_storing_context',
  'avoid_context_across_async',
  'avoid_context_after_await_in_static', // ERROR - context after await in static
  // Security
  'avoid_hardcoded_credentials',
  'avoid_logging_sensitive_data',
  // 'avoid_sensitive_data_in_logs' removed v4.2.3 - alias of avoid_sensitive_in_logs
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
  'avoid_dynamic_code_loading', // OWASP M2 - supply chain
  'avoid_unverified_native_library', // OWASP M2 - supply chain
  // Null Safety
  'avoid_null_assertion',
  'avoid_unsafe_collection_methods',
  'avoid_unsafe_where_methods',
  'avoid_unsafe_reduce',
  'avoid_late_final_reassignment',

  // Parameter Safety - Hidden side effects
  'avoid_parameter_mutation', // Mutating parameters modifies caller's data
  // State Management - Critical (Batch 10)
  'avoid_bloc_event_mutation', // Immutability is critical
  'require_initial_state', // Runtime crash without it
  'avoid_instantiating_in_bloc_value_provider', // Memory leak
  'avoid_existing_instances_in_bloc_provider', // Unexpected closure
  'avoid_instantiating_in_value_provider', // Memory leak (Provider package)
  'require_provider_dispose', // Resource cleanup
  'avoid_getx_context_outside_widget', // Unsafe context access outside widgets
  'avoid_hooks_outside_build', // Runtime error
  'avoid_conditional_hooks', // Runtime error
  // Forms - Critical (Batch 12)
  'require_form_key', // Forms won't work without it
  'avoid_clearing_form_on_error', // Data loss
  // Async
  'avoid_throw_in_finally',
  'avoid_uncaught_future_errors', // Alias: require_future_error_handling
  // Collections
  'avoid_duplicate_map_keys',
  'avoid_isar_enum_field',

  // Equatable (Essential - missing fields cause equality bugs)
  'list_all_equatable_fields',
  'avoid_mutable_field_in_equatable', // Mutable fields break equality
  // Architecture
  'avoid_circular_dependencies',

  // GetIt/DI (Essential - wrong usage)
  'avoid_functions_in_register_singleton',

  // Resource Management
  'require_native_resource_cleanup',
  'require_file_close_in_finally',
  'require_websocket_close',

  // Error Handling
  'avoid_swallowing_exceptions',
  'avoid_losing_stack_trace',

  'avoid_print_error', // Print for error logging loses errors in production
  // Collection/Loop Safety (Phase 2)
  'avoid_unreachable_for_loop',

  // Remaining ROADMAP_NEXT - resource cleanup
  'dispose_provided_instances',

  // Widget Structure
  'avoid_nested_scaffolds',
  'avoid_multiple_material_apps',

  // Build Method Anti-patterns (Critical)
  'avoid_dialog_in_build',
  'require_tab_controller_length_sync',

  // Scroll/List (Essential - prevent runtime errors and performance issues)
  'require_key_for_reorderable', // ERROR - reordering fails without keys
  'avoid_shrink_wrap_expensive', // WARNING - disables virtualization
  // Type Safety (Critical - throws runtime exceptions)
  'prefer_try_parse_for_dynamic_data',
  'avoid_double_for_money',

  // Animation (Essential - prevent crashes)
  'require_vsync_mixin',
  'require_animation_controller_dispose',
  'require_animation_ticker_disposal', // Ticker must be stopped to prevent memory leaks
  // Resource Management (Essential - prevent hardware lock)
  'require_camera_dispose',

  // Disposal Pattern Detection (Essential - memory leaks)
  'require_bloc_manual_dispose', // Bloc/Cubit with disposable resources
  'require_getx_worker_dispose', // GetX Workers must be disposed in onClose
  'require_getx_permanent_cleanup', // Get.put(permanent: true) needs cleanup
  'require_image_stream_dispose', // ImageStream listeners must be removed
  'require_sse_subscription_cancel', // SSE connections must be closed
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
  'avoid_test_sleep', // WARNING - blocks test runner, use pump() instead
  // QR/Camera (Essential - app store compliance)
  'require_qr_permission_check',
  'require_qr_content_validation', // Security - validate scanned content
  // PDF (Essential - memory safety)
  'avoid_loading_full_pdf_in_memory', // OOM prevention
  // Lifecycle (Essential - battery/stability)
  'require_lifecycle_observer',

  // Disposal (roadmap_up_next - memory leak)
  'require_stream_subscription_cancel',

  // Async (roadmap_up_next - runtime crash)
  'avoid_dialog_context_after_async',

  // ROADMAP ⭐ Rules - Essential
  'avoid_shared_prefs_in_isolate', // ERROR - SharedPreferences doesn't work in isolates
  'avoid_future_in_build', // ERROR - causes rebuilds and state issues
  'require_mounted_check_after_await', // ERROR - setState after dispose
  'provide_correct_intl_args', // ERROR - runtime crash from mismatched intl args
  'dispose_class_fields', // WARNING - memory leaks from undisposed fields
  'avoid_async_in_build', // ERROR - async build causes rendering issues
  // Package-specific rules (Essential - security/crash prevention)
  'require_apple_signin_nonce', // Security - replay attack prevention
  'avoid_supabase_anon_key_in_code', // Security - credential exposure
  'require_supabase_realtime_unsubscribe', // Memory leak - channel disposal
  'require_webview_ssl_error_handling', // Security - certificate validation
  'require_workmanager_result_return', // Crash prevention - task status
  'require_speech_stop_on_dispose', // Resource leak - microphone
  'avoid_app_links_sensitive_params', // Security - token exposure
  'avoid_openai_key_in_code', // Security - API key exposure
  // Part 5 - Security Rules (Essential)
  'avoid_shared_prefs_sensitive_data',
  'require_secure_storage_for_auth',
  'require_sqflite_whereargs',
  'require_hive_initialization',
  'require_hive_type_adapter',
  'require_hive_encryption_key_secure',
  'avoid_drift_enum_index_reorder', // ERROR - data corruption from enum .index storage
  'require_type_adapter_registration', // ERROR - adapter not registered before openBox
  'avoid_hive_field_index_reuse', // ERROR - data corruption from duplicate indices
  // Part 5 - HTTP/Dio Rules (Essential)
  'require_dio_timeout',
  'require_dio_error_handling',

  // Part 5 - Stream/Future Rules (Essential)
  'avoid_stream_in_build',
  'require_stream_controller_close',

  // Part 5 - Riverpod Rules (Essential)
  'require_riverpod_error_handling',
  'avoid_riverpod_state_mutation',

  // Part 5 - Navigation Rules (Essential)
  'avoid_go_router_inline_creation',

  // Part 5 - Geolocator Rules (Essential)
  'require_geolocator_permission_check',

  // Part 5 - Image Rules (Essential)
  'require_cached_image_dimensions',

  // Part 6 - State Management Rules (Essential)
  'avoid_yield_in_on_event', // Critical - deprecated/broken in Bloc 8.0+
  'emit_new_bloc_state_instances', // Critical - state mutation breaks equality
  'avoid_listen_in_async', // High - subscription leaks in async callbacks
  // Part 6 - Security Rules (Essential)
  'require_url_validation',
  'avoid_redirect_injection',
  'avoid_external_storage_sensitive',

  // Part 6 - Form Rules (Essential)
  'avoid_keyboard_overlap',
  'require_search_debounce', // Prevents request spam
  // Image Picker Rules (Essential - OOM prevention)
  'prefer_image_picker_max_dimensions', // WARNING - OOM on high-res cameras

  'avoid_unawaited_future', // WARNING - lost errors
  'avoid_catch_all', // WARNING - bare catch without on clause
  'avoid_catch_exception_alone', // WARNING - misses Error types
  'require_form_key_in_stateful_widget', // WARNING - form state loss
  'prefer_timeout_on_requests', // WARNING - hang prevention
  'avoid_bloc_context_dependency', // WARNING - testability
  'avoid_provider_value_rebuild', // WARNING - memory leak
  'avoid_notification_same_id', // WARNING - overwrites
  'require_intl_plural_rules', // WARNING - i18n correctness
  'require_mock_http_client', // WARNING - test reliability
  'require_image_cache_dimensions', // WARNING - OOM prevention
  'avoid_expanded_outside_flex', // ERROR - runtime crash
  'prefer_expanded_at_call_site', // ERROR - Expanded in build() crashes if misused
  'avoid_table_cell_outside_table', // ERROR - ParentData crash
  'avoid_positioned_outside_stack', // ERROR - ParentData crash
  'avoid_spacer_in_wrap', // ERROR - flex paradox crash
  'avoid_scrollable_in_intrinsic', // ERROR - geometry loop crash
  'require_baseline_text_baseline', // ERROR - assertion failure
  'avoid_unconstrained_dialog_column', // WARNING - probable dialog overflow
  'avoid_unbounded_listview_in_column', // ERROR - unbounded constraints crash
  'avoid_textfield_in_row', // ERROR - unbounded width crash
  'avoid_fixed_size_in_scaffold_body', // WARNING - probable keyboard overflow

  'require_test_widget_pump', // ERROR - flaky tests
  'require_hive_adapter_registration_order', // ERROR - runtime crash
  'require_hive_nested_object_adapter', // ERROR - runtime crash
  'avoid_api_key_in_code', // ERROR - security critical
  'avoid_storing_sensitive_unencrypted', // ERROR - security critical
  'avoid_ignoring_ssl_errors', // ERROR - MITM attack prevention (OWASP M5, A05)
  'require_https_only', // WARNING - unencrypted traffic (OWASP M5, A05)
  'avoid_unsafe_deserialization', // WARNING - data integrity (OWASP A08)
  'avoid_user_controlled_urls', // WARNING - SSRF prevention (OWASP A10)
  'require_catch_logging', // WARNING - security event logging (OWASP A09)
  'require_intl_args_match', // ERROR - runtime crash
  'require_cache_key_determinism', // ERROR - memory bloat
  'require_https_for_ios', // WARNING - ATS blocking
  'require_ios_permission_description', // WARNING - App Store rejection
  'require_ios_privacy_manifest', // WARNING - iOS 17+ requirement

  'require_apple_sign_in', // ERROR - App Store rejection

  'require_ios_app_tracking_transparency', // ERROR - App Store rejection without ATT
  'require_ios_face_id_usage_description', // WARNING - crash without Info.plist entry
  'avoid_ios_in_app_browser_for_auth', // ERROR - OAuth blocked by Google/Apple

  'require_ios_local_notification_permission', // WARNING - silent notification failures
  'require_ios_healthkit_authorization', // WARNING - silent data access failures
  'avoid_macos_catalyst_unsupported_apis', // WARNING - crashes on Mac Catalyst
  'require_ios_receipt_validation', // WARNING - IAP fraud prevention

  'avoid_long_running_isolates', // WARNING - iOS kills isolates after 30 seconds
  'require_purchase_verification', // ERROR - IAP receipt fraud prevention
  'require_purchase_restoration', // ERROR - App Store requires restore purchases
  'require_macos_notarization_ready', // INFO - macOS distribution requirement reminder
  'require_ios_data_protection', // WARNING - file encryption for sensitive data
  // =========================================================================
  // Orphan Rule Assignment (v4.1.0) - Previously untiered critical/high rules
  // =========================================================================

  // Security (Critical)
  'avoid_deep_link_sensitive_params', // ERROR - token exposure in deep links
  'avoid_path_traversal', // ERROR - directory traversal attack
  'require_data_encryption', // ERROR - sensitive data must be encrypted
  'require_secure_password_field', // ERROR - password field security
  // Platform/Permissions (Critical)
  'avoid_platform_channel_on_web', // ERROR - crashes on web
  // Widget Lifecycle (Critical/High)
  'avoid_ref_in_build_body', // ERROR - ref.watch in wrong place
  'avoid_flashing_content', // ERROR - accessibility seizure risk
  // Animation (High)
  'avoid_animation_rebuild_waste', // WARNING - animation performance
  'avoid_overlapping_animations', // WARNING - animation conflicts
  // Navigation (High)
  'require_deep_link_fallback', // WARNING - deep link error handling
  'require_stepper_validation', // WARNING - stepper form validation
  // Firebase/Backend (High)
  'prefer_firebase_remote_config_defaults', // WARNING - config defaults
  'require_background_message_handler', // WARNING - FCM background
  'require_fcm_token_refresh_handler', // WARNING - token refresh
  // WebView (High)
  'require_websocket_message_validation', // WARNING - message validation
  // Data/Storage (High)
  'prefer_utc_for_storage', // WARNING - timezone consistency
  'require_database_migration', // WARNING - migration safety
  // UI/UX (High)
  'prefer_html_escape', // WARNING - XSS prevention
  'require_error_widget', // WARNING - error boundary
  'require_feature_flag_default', // WARNING - feature flag safety
  'require_immutable_bloc_state', // WARNING - state immutability
  'require_map_idle_callback', // WARNING - map performance
  'require_media_loading_state', // WARNING - loading indicators
  // Network (High)
  'require_cors_handling', // WARNING - CORS on web
  // NEW v4.1.6 Rules - Essential
  'avoid_print_in_release', // ERROR - print() executes in release builds
  'avoid_sensitive_in_logs', // ERROR - no sensitive data in logs
  'prefer_platform_io_conditional', // ERROR - Platform checks crash on web
  'avoid_web_only_dependencies', // ERROR - dart:html crashes on mobile
  'require_date_format_specification', // WARNING - DateTime.parse may fail
  'avoid_optional_field_crash', // ERROR - null JSON field access crashes
  'avoid_hardcoded_config', // WARNING - hardcoded URLs and keys
  'avoid_mixed_environments', // ERROR - prod/dev config mismatch
  'require_late_initialization_in_init_state', // WARNING - late init in build()
  // NEW v4.1.7 Rules - Essential
  'require_websocket_reconnection', // WARNING - WebSocket needs reconnection
  'avoid_sensitive_data_in_clipboard', // WARNING - clipboard accessible to other apps
  'avoid_unbounded_cache_growth', // WARNING - caches without limits cause OOM
  // Critical disposal/state rules (auto-assigned by severity)
  'prefer_copy_with_for_state',
  'require_bloc_close',
  'require_error_state',
  'require_mounted_check',
  'require_scroll_controller_dispose',
  'require_tab_controller_dispose',
  'require_text_editing_controller_dispose',

  // Moved from Recommended (cause crashes, not just poor UX)
  'require_getit_registration_order', // startup crash
  'require_default_config', // startup crash
  'avoid_builder_index_out_of_bounds', // runtime crash
  'require_ios_keychain_for_credentials', // security critical - credential exposure
  // Note: require_purchase_verification already in Essential at line 421

  // =========================================================================
  // v4.2.0 ROADMAP ⭐ Rules - Essential
  // =========================================================================
  'require_android_permission_request', // ERROR - permissions must be requested at runtime
  'prefer_pending_intent_flags', // ERROR - PendingIntent needs FLAG_IMMUTABLE/MUTABLE
  'avoid_android_cleartext_traffic', // WARNING - cleartext traffic blocked by default
  'avoid_purchase_in_sandbox_production', // ERROR - sandbox/production environment mix
  'require_subscription_status_check', // WARNING - must check subscription status
  'require_location_permission_rationale', // WARNING - location permission needs rationale
  'require_camera_permission_check', // ERROR - camera needs permission check
  'require_firestore_index', // ERROR - Firestore queries need composite indexes
  'require_firebase_composite_index', // ERROR - RTDB queries need .indexOn rules
  'avoid_notification_silent_failure', // WARNING - notification failures should be handled
  'require_file_path_sanitization', // WARNING - file paths need sanitization
  'require_app_startup_error_handling', // WARNING - app startup needs error handling
  'avoid_assert_in_production', // WARNING - asserts don't run in production
  'prefer_lazy_loading_images', // WARNING - large images should be lazy loaded
  'avoid_sqflite_type_mismatch', // ERROR - SQLite type mismatches cause runtime errors
  'avoid_sudo_shell_commands', // ERROR - elevated privileges are a security risk
  // ROADMAP ⭐ Rules - Essential (new batch)
  'avoid_context_dependency_in_callback', // WARNING - stale context in async callbacks
  'avoid_hive_synchronous_in_ui', // WARNING - sync Hive I/O blocks UI thread
  // ROADMAP 🚨 Rules (Essential - ERROR severity)
  'prefer_correct_package_name', // ERROR - package naming convention
  'avoid_getx_build_context_bypass', // ERROR - bypasses BuildContext
  'avoid_permission_handler_null_safety', // ERROR - deprecated API
  'avoid_retaining_disposed_widgets', // ERROR - memory leak from widget refs
  'require_secure_key_generation', // ERROR - hardcoded encryption keys
  'require_hive_web_subdirectory', // ERROR - web storage conflicts
  // v4.14.0 - GitHub issue rules (Essential)
  'avoid_blocking_main_thread', // WARNING - sync I/O blocks main thread
  // v4.15.0 - ROADMAP ⭐ Rules (Essential)
  'avoid_cached_image_unbounded_list', // WARNING - unbounded image cache in lists
  // v4.16.0 - ROADMAP ⭐ Rules (Essential)
  'avoid_color_only_meaning', // WARNING - WCAG 1.4.1 color-only indicators
  'avoid_excessive_rebuilds_animation', // WARNING - too many widgets in builder
  'avoid_misused_hooks', // WARNING - hooks in callbacks/closures
  // v5.1.0 - Migration rules (Essential)
  'avoid_asset_manifest_json', // ERROR - removed in Flutter 3.38.0, runtime crash
  // v5.1.0 - Batch 2 (Essential)
  'require_auto_route_guard_resume', // WARNING - missing resolver.next()
  'require_auto_route_full_hierarchy', // WARNING - push() bypasses hierarchy
  // v5.1.0 - Batch 3 (Essential)
  'avoid_connectivity_equals_internet', // WARNING - ConnectivityResult != internet
};

/// Recommended tier rules - Essential + common mistakes, performance basics.
/// Catches bugs that don't immediately crash but cause poor UX, sluggish performance.
const Set<String> recommendedOnlyRules = <String>{
  // v5.1.0 - Migration rules (Recommended)
  'prefer_dropdown_initial_value', // WARNING - deprecated in Flutter 3.35.0
  'prefer_on_pop_with_result', // WARNING - deprecated in Flutter 3.35.0
  // Moved from Essential (style/quality, not crash prevention)
  // 'prefer_list_first' moved to stylisticRules (opinionated)
  // 'prefer_list_last' moved to stylisticRules (opinionated)
  'avoid_variable_shadowing',
  'avoid_string_substring',
  'prefer_single_container',
  'prefer_api_pagination',

  // v5.1.0 - New rules (Recommended)
  'avoid_cached_image_web',
  'avoid_void_async',
  'avoid_unused_constructor_parameters',
  'avoid_redundant_await',
  'avoid_redundant_null_check',
  'avoid_returning_null_for_void',
  'avoid_returning_null_for_future',
  'avoid_shadowing_type_parameters',

  // Database (Isar)
  'require_isar_nullable_field',

  // Database (Drift)
  'require_drift_database_close', // WARNING - resource leak from unclosed DB
  'avoid_drift_update_without_where', // WARNING - accidental bulk update/delete
  'require_await_in_drift_transaction', // WARNING - unawaited queries escape transaction
  'require_drift_foreign_key_pragma', // WARNING - foreign keys silently ignored
  'avoid_drift_raw_sql_interpolation', // ERROR - SQL injection
  'prefer_drift_batch_operations', // WARNING - loop inserts instead of batch
  'require_drift_stream_cancel', // WARNING - stream subscription memory leak
  // Database / IO (all DB packages + file I/O)
  'require_yield_after_db_write',
  'suggest_yield_after_db_read',
  'avoid_return_await_db',

  // BuildContext Safety (Recommended)
  // 'prefer_rethrow_over_throw_e' moved to stylisticRules (opinionated)
  'avoid_context_in_async_static', // WARNING - async static with context
  // Memory Management Best Practices
  'nullify_after_dispose',
  'require_auto_dispose',

  // Performance
  'avoid_expensive_build',
  'avoid_listview_without_item_extent',
  'avoid_shrink_wrap_in_lists',
  'avoid_mediaquery_in_build',
  'prefer_static_method',
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
  'require_key_for_collection', // Widgets in list builders need keys
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
  'require_semantic_label_icons',
  'require_accessible_images',
  'avoid_auto_play_media',

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
  'avoid_hardcoded_signing_config', // OWASP M7 - binary protection
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
  'avoid_unnecessary_setstate',
  'avoid_stateless_widget_initialized_fields',
  'avoid_state_constructors',
  'avoid_empty_text_widgets',
  'prefer_sized_box_for_whitespace',
  // 'prefer_sized_box_square' moved to stylisticRules (opinionated)
  // 'prefer_center_over_align' moved to stylisticRules (opinionated)
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
  // 'prefer_spacing_over_sizedbox' moved to stylisticRules (opinionated)
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
  'avoid_very_long_length_files', // 1000 lines - code smell (production files)
  'avoid_very_long_length_test_files', // 2000 lines - code smell (test files)
  'avoid_self_assignment',
  'avoid_self_compare',
  'avoid_assignments_as_conditions',
  'avoid_equal_expressions',
  'no_equal_then_else',
  'avoid_unnecessary_conditionals',
  'avoid_constant_conditions',
  'avoid_conditions_with_boolean_literals',
  'prefer_simpler_boolean_expressions',
  'no_empty_string',
  'avoid_misnamed_padding',
  // 'no_boolean_literal_compare' moved to stylisticRules (opinionated)

  // Collections
  'avoid_map_keys_contains',
  'avoid_collection_equality_checks',
  'avoid_missing_enum_constant_in_map',
  'avoid_enum_values_by_index',
  'prefer_where_or_null', // Prefer whereOrNull for idiomatic Dart

  'require_test_assertions',

  'avoid_hardcoded_test_delays',

  'avoid_test_coupling',

  'avoid_real_dependencies_in_tests',

  'prefer_test_wrapper',

  // State Management (Batch 10)
  'avoid_bloc_listen_in_build',

  // Performance (Batch 11)
  'avoid_memory_intensive_operations',
  'avoid_closure_memory_leak',
  'require_dispose_pattern',

  // Forms (Batch 12)
  'avoid_validation_in_build',

  // API & Network
  'require_http_status_check',
  'require_request_timeout', // (alias: require_api_timeout)
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

  // Note: prefer_boolean_prefixes, prefer_no_getter_prefix, prefer_wildcard_for_unused_param
  // moved to Stylistic tier

  // Security (Batch 14)
  'avoid_auth_state_in_prefs',

  // Accessibility (Batch 14)
  'require_button_semantics',
  'avoid_hover_only',

  // State Management (Batch 14)
  'prefer_ref_watch_over_read',
  'avoid_change_notifier_in_widget',
  // Note: require_provider_dispose is in Essential tier

  // Notification (Batch 14)
  'avoid_notification_payload_sensitive',

  // GetX (Batch 17)

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
  'require_form_auto_validate_mode',
  'require_autofill_hints',
  'prefer_on_field_submitted',

  // Duration & DateTime (Plan Group F)
  // 'prefer_duration_constants' moved to stylisticRules (opinionated)

  // UI/UX (Plan Groups G, J, K)
  'require_responsive_breakpoints',
  'require_currency_formatting_locale',
  'require_graphql_operation_names',

  // Internationalization - Format Rules (Recommended)
  'require_intl_date_format_locale', // DateFormat without locale varies by device
  'require_number_format_locale', // NumberFormat without locale varies by device
  'avoid_manual_date_formatting', // Manual date formatting is error-prone
  'require_intl_currency_format', // Manual currency formatting ignores locale
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

  // Package-specific rules (Recommended - error handling/best practices)
  'require_google_signin_error_handling', // Error handling - auth failures
  'require_supabase_error_handling', // Error handling - database failures
  'avoid_webview_file_access', // Security - file access restriction
  'require_workmanager_constraints', // Best practice - resource efficiency
  'require_calendar_timezone_handling', // Best practice - time zone handling
  'require_keyboard_visibility_dispose', // Memory - subscription cleanup
  'require_envied_obfuscation', // Security - env var protection
  'require_openai_error_handling', // Error handling - API rate limits
  'require_svg_error_handler', // UI stability - error fallback
  'require_google_fonts_fallback', // UI stability - font fallback
  // Part 5 - Security Rules (Recommended)
  'require_shared_prefs_null_handling',
  'require_shared_prefs_key_constants',

  // Part 5 - Navigation Rules (Recommended)
  'require_go_router_error_handler',

  // Part 5 - Image Rules (Recommended)
  'require_cached_image_placeholder',
  'require_cached_image_error_widget',

  // Part 5 - Stream Rules (Recommended)
  'avoid_multiple_stream_listeners',
  'require_stream_error_handling',

  // Part 6 - State Management Rules (Recommended)
  'prefer_consumer_over_provider_of',
  'require_async_value_order',
  'avoid_bloc_public_fields',

  // Part 6 - Theming Rules (Recommended)
  'require_dark_mode_testing',

  // Part 6 - UI/UX Rules (Recommended)
  'prefer_skeleton_over_spinner',
  'require_empty_results_state',
  'require_search_loading_indicator',
  'require_pagination_loading_state',

  // Part 6 - Lifecycle Rules (Recommended)
  'avoid_work_in_paused_state',
  'require_resume_state_refresh',

  // Part 6 - Firebase Rules (Recommended)
  'avoid_storing_user_data_in_auth',

  // Part 6 - Flutter Widget Rules (Recommended)
  'require_orientation_handling',

  // =========================================================================
  // ROADMAP_NEXT Parts 1-7 Rules (Recommended)
  // =========================================================================

  // Part 6 - Bloc Rules (Recommended - good practice)

  // Part 7 - Dio Rules (Recommended - maintainability)

  // Part 7 - Image Picker Rules (Recommended - UX)

  // Cached Image Rules (Recommended - UX)

  // Late Keyword Rules (Recommended - code quality)
  'prefer_late_final', // INFO - prefer late final for one-time init
  'avoid_late_for_nullable', // INFO - prefer nullable over late for optional
  // go_router Type Safety (Recommended - type safety)
  'prefer_go_router_extra_typed', // INFO - typed classes over Map/dynamic
  // Firebase Auth (Recommended - UX on web)
  'prefer_firebase_auth_persistence', // INFO - remember me on web
  // Test Rules (Recommended - test quality)
  'avoid_test_print_statements', // WARNING - use expect() instead
  'prefer_test_find_by_key', // INFO - prefer find.byKey over find.byType
  'prefer_setup_teardown', // INFO - extract repeated test setup
  'require_test_description_convention', // INFO - descriptive test names
  // Test Quality (New assignments)
  'avoid_real_network_calls_in_tests', // Ensures tests do not hit real network
  // Note: avoid_duplicate_test_assertions moved to Pedantic (pedantic)
  'require_error_case_tests', // Ensures error cases are tested
  'require_test_isolation', // Ensures tests do not share mutable state
  // Async Rules (Recommended - readability)
  'avoid_future_then_in_async', // WARNING - use await instead
  // Forms Rules (Recommended - UX)
  'require_text_input_type', // INFO - better keyboard for input
  'prefer_text_input_action', // INFO - better UX flow
  // Lifecycle Rules (Recommended - correctness)
  'require_did_update_widget_check', // WARNING - check widget changes
  // Equatable Rules (Recommended - immutability)
  'require_equatable_copy_with', // INFO - pattern for immutable updates
  // Image Rules (Recommended - performance)
  'prefer_cached_image_cache_manager', // INFO - optimize image caching
  // Navigation Rules (Recommended - clarity)
  'avoid_go_router_push_replacement_confusion', // WARNING - clear routing
  // Flutter Widget Rules (Recommended - correctness)
  'avoid_stack_without_positioned', // WARNING - layout correctness
  // =========================================================================
  // =========================================================================
  'require_integration_test_timeout', // WARNING - CI hang prevention
  'require_hive_field_default_value', // WARNING - migration safety
  'avoid_hive_box_name_collision', // WARNING - data corruption prevention
  'avoid_riverpod_notifier_in_build', // WARNING - state loss
  'require_riverpod_async_value_guard', // WARNING - error handling
  'avoid_bloc_business_logic_in_ui', // WARNING - testability
  'require_url_launcher_encoding', // WARNING - URL failure
  'avoid_nested_routes_without_parent', // WARNING - navigation issues
  'require_copy_with_null_handling', // WARNING - state management
  'avoid_string_concatenation_for_l10n', // WARNING - i18n correctness
  'avoid_blocking_database_ui', // WARNING - UI jank
  'avoid_money_arithmetic_on_double', // WARNING - precision issues
  'avoid_rebuild_on_scroll', // WARNING - memory leak
  'avoid_exception_in_constructor', // WARNING - error handling
  'require_permission_permanent_denial_handling', // WARNING - UX
  // Note: require_getit_registration_order, require_default_config, avoid_builder_index_out_of_bounds
  // moved to Essential (they cause crashes)
  'prefer_ios_safe_area', // INFO - iOS notch/Dynamic Island handling
  'avoid_ios_hardcoded_status_bar', // WARNING - device-specific issues
  'require_macos_window_size_constraints', // INFO - UX

  'avoid_ios_13_deprecations', // WARNING - App Store warnings
  'avoid_ios_simulator_only_code', // WARNING - production failures
  'require_ios_minimum_version_check', // INFO - version compatibility

  'require_ios_photo_library_add_usage', // WARNING - crash without permission
  'require_ios_app_review_prompt_timing', // WARNING - App Store rejection
  'require_ios_push_notification_capability', // INFO - silent push failures

  'avoid_ios_hardcoded_device_model', // WARNING - breaks on new devices
  'require_ios_app_group_capability', // INFO - extension data sharing

  'avoid_ios_continuous_location_tracking', // INFO - battery optimization
  'require_app_lifecycle_handling', // INFO - proper app lifecycle
  'require_ios_nfc_capability_check', // WARNING - device compatibility
  'require_ios_callkit_integration', // WARNING - VoIP requirement
  'require_ios_photo_library_limited_access', // INFO - iOS 14+ handling

  'require_ios_method_channel_cleanup', // WARNING - memory leak prevention
  'avoid_ios_force_unwrap_in_callbacks', // WARNING - crash prevention
  'require_ios_deployment_target_consistency', // WARNING - API compatibility
  'require_ios_dynamic_island_safe_zones', // WARNING - device layout
  // Note: require_ios_keychain_for_credentials moved to Essential (security critical)
  'require_macos_sandbox_entitlements', // WARNING - App Store requirement
  'avoid_macos_full_disk_access', // WARNING - prefer scoped access

  'require_workmanager_for_background', // WARNING - Dart isolates die on background
  'require_notification_for_long_tasks', // WARNING - show progress for long operations
  'prefer_delayed_permission_prompt', // WARNING - don't request permission on launch
  'avoid_notification_spam', // WARNING - batch notifications properly
  'require_ios_low_power_mode_handling', // WARNING - adapt to Low Power Mode
  'require_ios_accessibility_large_text', // WARNING - support Dynamic Type
  'avoid_ios_hardcoded_keyboard_height', // WARNING - use viewInsets.bottom
  'require_ios_multitasking_support', // WARNING - iPad Split View/Slide Over
  'avoid_ios_battery_drain_patterns', // WARNING - inefficient battery usage
  'avoid_ios_wifi_only_assumption', // WARNING - check connectivity for downloads
  'require_macos_sandbox_exceptions', // WARNING - sandbox entitlements documentation
  'avoid_macos_hardened_runtime_violations', // WARNING - notarization compliance
  'require_macos_app_transport_security', // WARNING - macOS ATS compliance
  // v2.6.0 rules (ROADMAP_NEXT)
  // 'prefer_returning_conditional_expressions' moved to stylisticRules (opinionated)
  'prefer_riverpod_family_for_params', // INFO - type-safe parameters
  'require_dio_response_type', // INFO - explicit response types
  'require_go_router_fallback_route', // INFO - error handling
  'prefer_sqflite_column_constants', // INFO - avoid typos
  'require_freezed_lint_package', // INFO - Freezed best practices
  'prefer_image_picker_multi_selection', // INFO - better UX
  'prefer_hive_value_listenable', // INFO - reactive UI
  // =========================================================================
  // Orphan Rule Assignment (v4.1.0) - Previously untiered medium rules
  // =========================================================================

  // Widget Structure (Medium)
  'avoid_deep_widget_nesting', // INFO - widget depth warning
  'avoid_find_child_in_build', // INFO - avoid widget finding in build
  'avoid_layout_builder_in_scrollable', // INFO - layout builder misuse
  'avoid_nested_providers', // INFO - provider nesting
  'avoid_opacity_misuse', // INFO - opacity performance
  'avoid_unbounded_constraints', // INFO - constraint issues
  'avoid_unconstrained_box_misuse', // INFO - UnconstrainedBox misuse
  // Gesture/Input (Medium)
  'avoid_double_tap_submit', // INFO - double tap prevention
  'avoid_gesture_conflict', // INFO - gesture detector conflicts
  'avoid_gesture_without_behavior', // INFO - HitTestBehavior missing
  'prefer_actions_and_shortcuts', // INFO - keyboard shortcuts
  'prefer_cursor_for_buttons', // INFO - cursor on clickable
  'require_disabled_state', // INFO - disabled button state
  'require_drag_feedback', // INFO - drag feedback
  'require_focus_indicator', // INFO - focus visibility
  'require_hover_states', // INFO - hover feedback
  'require_long_press_callback', // INFO - long press handler
  // Forms/Validation (Medium)
  'require_button_loading_state', // INFO - loading state on buttons
  'require_form_validation', // INFO - form validation
  'require_step_count_indicator', // INFO - stepper indicators
  // Testing (Medium)
  'avoid_flaky_tests', // INFO - test reliability
  'avoid_real_timer_in_widget_test', // INFO - fake timers in tests
  'avoid_stateful_test_setup', // INFO - test setup pattern
  'prefer_matcher_over_equals', // INFO - test matchers
  'prefer_mock_http', // INFO - mock HTTP in tests
  'require_golden_test', // INFO - golden tests
  'require_mock_verification', // INFO - mock verification
  'require_riverpod_lint', // INFO - Riverpod linting
  'require_screen_size_tests', // INFO - responsive tests
  // Performance (Medium)
  'avoid_hardcoded_layout_values', // INFO - layout flexibility
  'avoid_hardcoded_text_styles', // INFO - text style theming
  'avoid_large_images_in_memory', // INFO - image memory
  'avoid_map_markers_in_build', // INFO - map marker creation
  'prefer_clip_behavior', // INFO - clip behavior
  'prefer_deferred_loading_web', // INFO - web bundle splitting
  'prefer_fit_cover_for_background', // INFO - BoxFit.cover
  'prefer_fractional_sizing', // INFO - fractional vs fixed
  'prefer_intrinsic_dimensions', // INFO - intrinsic sizing
  'prefer_keep_alive', // INFO - AutomaticKeepAliveClientMixin
  'prefer_page_storage_key', // INFO - scroll position persistence
  'prefer_positioned_directional', // INFO - RTL support
  'prefer_sliver_app_bar', // INFO - sliver app bars
  'prefer_sliver_list', // INFO - sliver lists
  // State Management (Medium)
  'avoid_late_context', // INFO - late context access
  // Note: prefer_cubit_for_simple_state is in Professional tier (architecture pattern)

  // Accessibility (Medium)
  'avoid_screenshot_sensitive', // INFO - screenshot protection
  'avoid_semantics_exclusion', // INFO - semantics exclusion
  'prefer_merge_semantics', // INFO - merge semantics
  // 'avoid_small_text' moved to stylisticRules (opinionated)

  // Data/Collections (Medium)
  'avoid_misused_set_literals', // INFO - set literal usage
  'move_variable_closer_to_its_usage', // INFO - variable scope
  // Images/Media (Medium)
  'prefer_asset_image_for_local', // INFO - local image loading
  'prefer_marker_clustering', // INFO - map marker clustering
  'require_pdf_loading_indicator', // INFO - PDF loading state
  // Database (Medium)
  'require_database_index', // INFO - database indexes
  'prefer_transaction_for_batch', // INFO - batch transactions
  // Navigation (Medium)
  'prefer_typed_route_params', // INFO - typed route parameters
  'require_refresh_indicator', // INFO - pull to refresh
  'require_scroll_controller', // INFO - scroll controller
  'require_scroll_physics', // INFO - scroll physics
  // Security (Medium)
  'prefer_clipboard_feedback', // INFO - clipboard feedback
  'prefer_data_masking', // INFO - sensitive data masking
  // Desktop/Platform (Medium)
  'require_menu_bar_for_desktop', // INFO - desktop menu bar
  'require_window_close_confirmation', // INFO - unsaved changes
  // Animation (Medium)
  'prefer_tween_sequence', // INFO - tween sequences
  // i18n (Medium)

  // Misc (Medium)
  'prefer_adequate_spacing', // INFO - spacing consistency
  'prefer_safe_area_aware', // INFO - safe area handling
  'prefer_wrap_over_overflow', // INFO - overflow handling
  'require_default_text_style', // INFO - text style defaults
  // Note: prefer_sorted_pattern_fields, prefer_sorted_record_fields moved to Stylistic

  // Additional orphans (missed in initial pass)
  'prefer_ignore_pointer', // INFO - IgnorePointer for non-interactive
  // cspell:ignore namespacing
  // ROADMAP ⭐ Rules - Recommended
  'avoid_passing_bloc_to_bloc', // WARNING - blocs should communicate via repository
  'avoid_passing_build_context_to_blocs', // WARNING - blocs shouldn't hold context
  'avoid_returning_value_from_cubit_methods', // WARNING - use state instead
  'prefer_bloc_hydration', // INFO - persist state across restarts
  'avoid_getx_dialog_snackbar_in_controller', // WARNING - UI logic in controller
  'require_getx_lazy_put', // INFO - prefer lazyPut for efficiency
  'prefer_hive_lazy_box', // INFO - better memory management
  'avoid_hive_binary_storage', // WARNING - binary data integrity issues
  'require_shared_prefs_prefix', // INFO - organized key namespacing
  'prefer_shared_prefs_async_api', // INFO - async API for better performance
  'prefer_stream_distinct', // INFO - prevent redundant emissions
  'prefer_broadcast_stream', // INFO - prefer broadcast for multiple listeners
  'prefer_async_init_state', // INFO - use dedicated async init patterns
  'require_widgets_binding_callback', // WARNING - dialogs in initState need callback
  'prefer_route_settings_name', // INFO - named routes for debugging
  'prefer_number_format', // INFO - use NumberFormat for localized numbers
  'prefer_change_notifier_proxy_provider', // INFO - ProxyProvider for dependent notifiers
  // NEW v4.1.5 Rules - Recommended
  'avoid_di_in_widgets', // WARNING - DI service locator shouldn't be in widgets
  'prefer_abstraction_injection', // INFO - inject abstractions not implementations
  'prefer_large_touch_targets', // INFO - WCAG touch target guidelines
  'avoid_global_keys_in_state', // WARNING - GlobalKey in State causes issues
  'require_flutter_riverpod_not_riverpod', // ERROR - Flutter apps need flutter_riverpod
  'avoid_navigator_context_issue', // ERROR - GlobalKey context in navigation
  'avoid_push_replacement_misuse', // WARNING - pushReplacement for detail pages
  'avoid_string_concatenation_l10n', // WARNING - string concat breaks i18n
  'avoid_time_limits', // INFO - short durations hurt accessibility
  'require_network_status_check', // INFO - check connectivity before requests
  'avoid_sync_on_every_change', // WARNING - debounce API calls in onChanged
  'require_firebase_error_handling', // WARNING - Firebase calls need error handling
  'require_secure_storage_error_handling', // WARNING - secure storage needs error handling
  // NEW v4.1.6 Rules - Recommended
  'prefer_foundation_platform_check', // INFO - use defaultTargetPlatform in widgets
  'prefer_explicit_json_keys', // INFO - use @JsonKey for field mapping
  // NEW v4.1.7 Rules - Recommended
  'require_dialog_tests', // INFO - dialog tests need pumpAndSettle
  'require_clipboard_paste_validation', // INFO - validate clipboard paste
  'require_currency_code_with_amount', // INFO - amounts need currency
  'require_cache_expiration', // WARNING - caches need TTL
  'require_dialog_barrier_consideration', // INFO - destructive dialogs need barrierDismissible
  // Common warnings (auto-assigned by severity)
  'avoid_accessing_collections_by_constant_index',
  'avoid_assigning_to_static_field',
  'avoid_bitwise_operators_with_booleans',
  'avoid_bloc_in_bloc',
  'avoid_bottom_type_in_patterns',
  'avoid_bottom_type_in_records',
  'avoid_build_context_in_providers',
  'avoid_cascade_after_if_null',
  'avoid_casting_to_extension_type',
  'avoid_collection_methods_with_unrelated_types',
  'avoid_constant_assert_conditions',
  'avoid_constant_switches',
  'avoid_context_in_initstate_dispose',
  'avoid_contradictory_expressions',
  'avoid_controller_in_build',
  'avoid_debug_print',
  'avoid_double_slash_imports',
  'avoid_duplicate_number_elements',
  'avoid_duplicate_string_elements',
  'avoid_duplicate_object_elements',
  'avoid_duplicate_exports',
  'avoid_duplicate_mixins',
  'avoid_duplicate_named_imports',
  'avoid_duplicate_patterns',
  'avoid_duplicate_switch_case_conditions',
  'avoid_empty_spread',
  'avoid_empty_test_groups',
  'avoid_generic_key_in_url',
  'avoid_global_state',
  'avoid_implicitly_nullable_extension_types',
  'avoid_incorrect_image_opacity',
  'avoid_incorrect_uri',
  'avoid_keywords_in_wildcard_pattern',
  'avoid_missing_completer_stack_trace',
  'avoid_nested_assignments',
  'avoid_non_final_exception_class_fields',
  'avoid_nullable_interpolation',
  'avoid_nullable_parameters_with_default_values',
  'avoid_only_rethrow',
  'avoid_passing_async_when_sync_expected',
  'avoid_referencing_discarded_variables',
  'avoid_regex_in_loop',
  'avoid_secure_storage_on_web',
  'avoid_shadowed_extension_methods',
  'avoid_singlechildscrollview_with_column',
  'avoid_throw_in_catch_block',
  'avoid_unassigned_late_fields',
  'avoid_unconditional_break',
  'avoid_unguarded_debug',
  'avoid_unknown_pragma',
  'avoid_unnecessary_reassignment',
  'avoid_unnecessary_statements',
  'avoid_unused_generics',
  'avoid_unused_instances',
  'avoid_wildcard_cases_with_enums',
  'avoid_wildcard_cases_with_sealed_classes',
  'dispose_provider_instances',
  'dispose_widget_fields',
  'function_always_returns_null',
  'match_class_name_pattern',
  'no_equal_arguments',
  'no_equal_conditions',
  'no_equal_nested_conditions',
  'pass_correct_accepted_type',
  'prefer_correct_type_name',
  'prefer_define_hero_tag',
  'prefer_overriding_parent_equality',
  'prefer_specific_cases_first',
  'require_integration_test_setup',
  'require_timer_cancellation',
  'use_setstate_synchronously',

  // =========================================================================
  // v4.2.0 ROADMAP ⭐ Rules - Recommended
  // =========================================================================
  'require_android_12_splash', // INFO - Android 12+ requires SplashScreen API
  'require_price_localization', // INFO - IAP prices should be localized
  'require_url_launcher_can_launch_check', // INFO - check canLaunchUrl before launchUrl
  'avoid_url_launcher_simulator_tests', // INFO - URL launcher doesn't work in simulator
  'prefer_url_launcher_fallback', // INFO - provide fallback when URL can't be launched
  'require_connectivity_error_handling', // INFO - connectivity checks need error handling
  'prefer_image_cropping', // INFO - allow image cropping for user uploads
  'prefer_json_serializable', // INFO - prefer json_serializable over manual parsing
  'prefer_regex_validation', // INFO - use regex for input validation patterns
  'prefer_freezed_for_data_classes', // INFO - Freezed for immutable data classes
  // --- Restored orphan rules (critical impact) ---
  'avoid_bloc_emit_after_close',
  'avoid_bloc_state_mutation',
  'avoid_dynamic_json_chains',
  'avoid_freezed_json_serializable_conflict',
  'avoid_isar_clear_in_production',
  'avoid_isar_transaction_nesting',
  'avoid_navigation_in_build',
  'avoid_not_encodable_in_to_json',
  'avoid_set_state_in_dispose',
  'avoid_stream_subscription_in_field',
  'avoid_unrelated_type_casts',
  'avoid_websocket_memory_leak',
  'avoid_webview_insecure_content',
  'check_mounted_after_async',
  'prefer_dispose_before_new_instance',
  'proper_getx_super_calls',
  'require_bloc_initial_state',
  'require_change_notifier_dispose',
  'require_connectivity_subscription_cancel',
  'require_database_close',
  'require_debouncer_cancel',
  'require_dispose_implementation',
  'require_equatable_props_override',
  'require_flutter_riverpod_package',
  'require_freezed_arrow_syntax',
  'require_freezed_private_constructor',
  'require_https_over_http',
  'require_image_picker_permission_android',
  'require_image_picker_permission_ios',
  'require_interval_timer_cancel',
  'require_isar_collection_annotation',
  'require_isar_id_field',
  'require_notification_handler_top_level',
  'require_null_safe_json_access',
  'require_permission_manifest_android',
  'require_permission_plist_ios',
  'require_provider_generic_type',
  'require_receive_port_close',
  'require_secure_storage_auth_data',
  'require_socket_close',
  'require_super_dispose_call',
  'require_super_init_state_call',
  'require_url_launcher_queries_android',
  'require_url_launcher_schemes_ios',
  'require_validator_return_null',

  // Windows/Linux platform rules (Recommended)
  'avoid_hardcoded_drive_letters', // WARNING - hardcoded drive letters break portability
  'avoid_forward_slash_path_assumption', // WARNING - forward-slash paths fail on Windows
  'avoid_case_sensitive_path_comparison', // WARNING - path comparison must be case-insensitive on Windows
  'avoid_hardcoded_unix_paths', // WARNING - hardcoded Unix paths break portability
  'avoid_x11_only_assumptions', // WARNING - X11-only code fails on Wayland
  'require_video_player_controller_dispose',
  'require_wss_over_ws',

  // ROADMAP ⭐ Rules - Recommended (new batch)
  'avoid_missing_interpolation', // WARNING - use string interpolation over +
  'avoid_provider_listen_false_in_build', // INFO - stale data from listen: false
  'prefer_spring_animation', // INFO - natural physics-based animation
  'prefer_avatar_loading_placeholder', // INFO - fallback for network avatars
  // v4.14.0 - GitHub issue rules (Recommended)
  'require_feature_flag_type_safety', // INFO - typed feature flag accessors
  'require_timezone_display', // INFO - timezone context in time display
  // v4.15.0 - ROADMAP ⭐ Rules (Recommended)
  'require_analytics_error_handling', // INFO - analytics calls need try-catch
  'prefer_adaptive_icons', // INFO - use adaptive icon sizes
  'avoid_ignoring_return_values', // INFO - don't discard return values
  // v4.16.0 - ROADMAP ⭐ Rules (Recommended)
  'require_rtl_layout_support', // WARNING - hardcoded left/right in layouts
  'avoid_misused_test_matchers', // WARNING - raw literals as test matchers
  // v5.1.0 - Batch 3 (Recommended)
  'avoid_string_env_parsing', // WARNING - fromEnvironment without defaultValue
  'avoid_platform_specific_imports', // WARNING - dart:io in shared code
  'avoid_shared_prefs_sync_race', // WARNING - un-awaited SharedPreferences writes
  'avoid_stack_trace_in_production', // WARNING - stack trace exposed to users
};

/// Professional tier rules - Recommended + architecture, testing, maintainability.
/// Includes stricter naming conventions for API parameters.
const Set<String> professionalOnlyRules = <String>{
  // Type Safety (moved from Essential - not crash prevention)
  'avoid_dynamic_type', // Type safety best practice
  // Widget Best Practices
  'prefer_widget_private_members', // Widget fields should be final/private
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
  'prefer_uuid_v4', // UUID v4 over v1 for privacy
  'require_https_only_test', // INFO - HTTP URLs in test files
  'avoid_hardcoded_config_test', // INFO - hardcoded config in test files
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
  'require_error_boundary',
  // Note: require_async_error_documentation moved to Comprehensive

  // Performance
  'require_keys_in_animated_lists',
  'avoid_synchronous_file_io', // also covered by avoid_blocking_main_thread (Essential)
  'prefer_compute_for_heavy_work',
  'prefer_cached_getter',
  // Note: avoid_object_creation_in_hot_loops moved to Pedantic (micro-optimization)
  'require_item_extent_for_large_lists',
  // Note: require_image_cache_dimensions is in Essential (OOM prevention)
  'avoid_layout_builder_misuse',
  'avoid_repaint_boundary_misuse',
  'avoid_gesture_detector_in_scrollview',
  'prefer_opacity_widget',
  'avoid_layout_passes',
  'avoid_unnecessary_to_list',
  'avoid_global_key_misuse',
  'avoid_unconstrained_images',
  // Note: prefer_image_precache, avoid_excessive_widget_depth, prefer_sliver_list_delegate,
  // require_repaint_boundary, prefer_typed_data moved to Comprehensive

  // Note: prefer_item_extent, prefer_prototype_item, require_add_automatic_keep_alives_off
  // moved to Comprehensive (optimization hints)

  // Forms/UX
  'prefer_autovalidate_on_interaction',
  'require_keyboard_type',
  'require_text_overflow_in_row',
  'require_error_message_context',

  // Riverpod (Professional - cleaner patterns)
  'avoid_notifier_constructors',
  // Note: prefer_equatable_mixin, prefer_void_callback, prefer_symbol_over_key,
  // prefer_immutable_provider_arguments moved to Comprehensive

  // Provider (Professional - type safety)
  'prefer_nullable_provider_types',

  // Bloc (Professional - cleaner patterns)
  // Note: prefer_immutable_bloc_events, prefer_immutable_bloc_state,
  // prefer_sealed_bloc_events, prefer_sealed_bloc_state moved to Comprehensive
  // require_bloc_repository_abstraction moved to Pedantic

  // State Management (Batch 10)
  'avoid_expensive_computation_in_build',
  'require_image_cache_management',
  'require_submit_button_state',
  'require_form_field_controller',
  'avoid_production_config_in_tests',
  'require_test_setup_teardown',
  'prefer_unique_test_names',
  'prefer_test_structure',
  'prefer_test_matchers',
  'prefer_pump_and_settle',
  'require_test_groups',
  'require_edge_case_tests',
  'avoid_test_implementation_details',
  'avoid_find_by_text', // INFO - prefer find.byKey for interactions
  'require_test_keys', // INFO - widgets in tests should have keys
  'require_arrange_act_assert', // INFO - AAA pattern for test structure
  'prefer_mock_navigator', // INFO - mock navigator for verification
  'prefer_bloc_test_package', // INFO - use blocTest() for Bloc testing
  'prefer_mock_verify', // INFO - verify mock interactions
  'require_error_logging', // INFO - log errors in catch blocks
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
  'verify_documented_parameters_exist',

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
  'no_empty_block', // INFO - empty blocks indicate incomplete code
  'avoid_medium_length_files', // 300 lines - starting to get complex (production files)
  'avoid_medium_length_test_files', // 600 lines - starting to get complex (test files)
  'avoid_long_functions',
  'avoid_long_parameter_list',
  'avoid_generics_shadowing',
  'avoid_unmarked_public_class',
  'prefer_final_class',
  'prefer_interface_class',
  'prefer_base_class',
  'avoid_similar_names',
  'avoid_unused_parameters',
  'avoid_duplicate_cascades',
  'avoid_complex_conditions',
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
  // Note: prefer_providing_intl_description, prefer_providing_intl_examples moved to Pedantic

  // API & Network
  'require_retry_logic',
  'require_typed_api_response',
  'require_api_error_mapping',
  'require_connectivity_check',
  'require_offline_indicator',
  'require_cancel_token', // WARNING - cancel requests on dispose
  // Note: prefer_http_connection_reuse, avoid_redundant_requests moved to Comprehensive

  // Resource Management
  'require_http_client_close',
  'require_platform_channel_cleanup',
  'require_isolate_kill',
  'require_image_compression',
  // Note: prefer_coarse_location_when_sufficient moved to Comprehensive

  // Animation (Professional - polish)
  'avoid_hardcoded_duration',
  'require_animation_curve',
  'prefer_implicit_animations',
  // Note: require_staggered_animation_delays moved to Comprehensive

  // Navigation (Professional - consistency)
  'require_route_transition_consistency',
  'avoid_pop_without_result',
  'prefer_shell_route_for_persistent_ui',

  // Type Safety
  // Note: prefer_constrained_generics, prefer_explicit_type_arguments moved to Comprehensive
  // Note: prefer_specific_numeric_types moved to Pedantic
  // Note: require_covariant_documentation, require_futureor_documentation moved to Comprehensive

  // Naming & Style
  // 'prefer_boolean_prefixes_for_params' moved to stylisticRules (opinionated)

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
  'prefer_ios_storekit2', // INFO - StoreKit 2 for better IAP
  // Gap Analysis Rules (Batch 15)
  'avoid_duplicate_string_literals',
  // Note: avoid_returning_widgets, avoid_nullable_widget_methods moved to Pedantic
  'avoid_setstate_in_large_state_class',

  // State Management (Batch 17)
  'require_bloc_transformer',
  // Note: prefer_notifier_over_state moved to Comprehensive
  'avoid_long_event_handlers',

  // Performance (Batch 17)
  'prefer_builder_for_conditional',
  // Note: require_list_preallocate moved to Comprehensive
  'require_widget_key_strategy',

  // Image & Media (Plan Group A)
  // Note: avoid_image_rebuild_on_scroll moved to Comprehensive

  // Dialog & Snackbar (Plan Group D)
  'require_dialog_result_handling',
  'avoid_snackbar_queue_buildup',

  // UI/UX (Plan Groups J, K)
  'require_custom_painter_shouldrepaint',
  'require_number_formatting_locale',
  'avoid_badge_without_meaning',
  'prefer_logger_over_print',
  'require_tab_state_preservation',
  // Note: prefer_cached_paint_objects, prefer_itemextent_when_known moved to Comprehensive

  // Hardware (Plan Group H)
  'require_audio_focus_handling',
  // Note: prefer_ble_mtu_negotiation moved to Comprehensive

  // QR Scanner (Plan Group I)
  'avoid_qr_scanner_always_active',

  // GraphQL (Plan Group K)
  'avoid_graphql_string_queries', // Type safety - use codegen
  // Image (Plan Group A)
  'prefer_image_size_constraints',

  // Phase 2 Rules - Widget Optimization
  'prefer_for_loop_in_children',
  // Note: prefer_compute_over_isolate_run moved to Comprehensive
  // Note: prefer_immutable_selector_value, prefer_provider_extensions moved to Comprehensive

  // Phase 2 Rules - Code Quality
  // Note: prefer_typedefs_for_callbacks, prefer_redirecting_superclass_constructor moved to Comprehensive

  // Phase 2 Rules - Bloc Naming
  // Note: prefer_bloc_event_suffix, prefer_bloc_state_suffix moved to Comprehensive

  // Phase 2 Rules - Hooks
  // Note: prefer_use_prefix moved to Comprehensive

  // Firebase rules (roadmap_up_next)
  'prefer_firestore_batch_write',

  // Animation rules (roadmap_up_next)
  'require_animation_status_listener',

  // Platform rules (roadmap_up_next)
  'avoid_touch_only_gestures',
  'avoid_circular_imports',

  // Test rules (roadmap_up_next)
  'require_test_cleanup',
  // Note: require_accessibility_tests, prefer_test_data_builder, prefer_test_variant,
  // require_animation_tests moved to Comprehensive

  // Part 5 - Database Rules (Professional)
  'avoid_drift_database_on_main_isolate', // INFO - UI jank from main thread DB
  'avoid_drift_log_statements_production', // WARNING - SQL logging in production
  'avoid_drift_get_single_without_unique', // INFO - getSingle on multi-row query
  'prefer_drift_use_columns_false', // INFO - unnecessary column reads on joins
  'avoid_drift_lazy_database', // INFO - LazyDatabase breaks isolate sync
  'prefer_drift_isolate_sharing', // INFO - multiple instances break stream sync
  'require_sqflite_transaction',
  'prefer_sqflite_batch',
  'require_sqflite_error_handling',
  'require_sqflite_close',
  'avoid_sqflite_reserved_words', // SQLite reserved words cause syntax errors
  'require_hive_box_close',
  'prefer_hive_encryption',
  'require_hive_database_close', // WARNING - database opened without close method
  // Note: prefer_lazy_box_for_large moved to Comprehensive

  // Part 5 - Dio Rules (Professional)
  'require_dio_interceptor_error_handler',
  'prefer_dio_cancel_token',
  'require_dio_ssl_pinning',
  'avoid_dio_form_data_leak',

  // Part 5 - Async Rules (Professional)
  'require_future_timeout',

  // Part 5 - Riverpod Rules (Professional)
  'prefer_riverpod_select',

  // Part 5 - Navigation Rules (Professional)
  'require_go_router_refresh_listenable',
  'avoid_go_router_string_paths',

  // Part 5 - Geolocator Rules (Professional)
  'require_geolocator_service_enabled',
  'require_geolocator_stream_cancel',
  'require_geolocator_error_handling',
  // Note: prefer_geolocator_distance_filter moved to Comprehensive

  // Part 6 - State Management Rules (Professional)
  'avoid_bloc_public_methods',
  'require_bloc_selector',

  // Part 6 - Firebase Rules (Professional)
  'require_crashlytics_user_id',
  'require_firebase_app_check',

  // Part 6 - Theming Rules (Professional)
  'avoid_elevation_opacity_in_dark',
  'prefer_theme_extensions',

  // Part 6 - Security Rules (Professional)
  'prefer_local_auth',

  // Part 6 - Performance Rules (Professional)
  // Note: prefer_inherited_widget_cache, prefer_layout_builder_over_media_query moved to Comprehensive

  // Part 6 - Flutter Widget Rules (Professional)
  'require_should_rebuild',
  'require_web_renderer_awareness',

  // Part 6 - Additional Rules (Professional)
  'require_exif_handling',
  'prefer_adaptive_dialog',
  'require_snackbar_action_for_undo',
  'require_content_type_check',
  'avoid_websocket_without_heartbeat',
  'prefer_iterable_operations',
  // 'prefer_dot_shorthand' moved to stylisticRules (opinionated)
  'require_future_wait_error_handling',
  'require_stream_on_done',
  'require_completer_error_handling',

  // =========================================================================
  // ROADMAP_NEXT Parts 1-7 Rules (Professional)
  // =========================================================================

  // Part 1 - Isar Database Rules (Professional - optimization)

  // Part 7 - Dio Rules (Professional - architecture)

  // Part 7 - GoRouter Rules (Professional - best practice)

  // Part 7 - Provider Rules (Professional - best practice)

  // Part 7 - Hive Rules (Professional - data integrity)

  // Part 7 - Image Picker Rules (Professional - error handling)

  // Part 7 - Cached Image Rules (Professional - performance)

  // Part 7 - SQLite Rules (Professional - migration safety)

  // Part 7 - Permission Rules (Professional - UX/compliance)

  // URL Launcher Rules (Professional - consistency)

  // SQLite Rules (Professional - performance)

  // Navigation Rules (Professional - type safety)
  'prefer_url_launcher_uri_over_string', // INFO - type-safe URI
  // API/Network Rules (Professional - architecture)
  'prefer_dio_over_http', // INFO - better features, interceptors

  'require_ios_background_mode', // INFO - background capabilities
  'avoid_ios_deprecated_uikit', // WARNING - deprecated UIKit APIs

  'require_ios_keychain_accessibility', // INFO - security best practice
  'avoid_ios_hardcoded_bundle_id', // INFO - deployment flexibility
  'require_macos_file_access_intent', // INFO - sandbox compliance
  'avoid_macos_deprecated_security_apis', // WARNING - notarization issues

  'require_ios_ats_exception_documentation', // INFO - ATS documentation
  'require_macos_hardened_runtime', // INFO - notarization requirements
  'require_ios_siri_intent_definition', // INFO - SiriKit setup
  'require_ios_widget_extension_capability', // INFO - WidgetKit setup

  'require_ios_database_conflict_resolution', // INFO - sync conflict handling
  'require_ios_background_audio_capability', // INFO - background audio setup
  'require_ios_app_clip_size_limit', // INFO - App Clip bundle size
  'require_ios_keychain_sync_awareness', // INFO - iCloud Keychain sync
  'require_ios_share_sheet_uti_declaration', // INFO - UTI for file sharing
  'require_ios_icloud_kvstore_limitations', // INFO - iCloud KV storage limits
  'require_ios_orientation_handling', // INFO - orientation configuration
  'require_ios_universal_links_domain_matching', // INFO - Universal Links paths
  'require_ios_carplay_setup', // INFO - CarPlay entitlement
  'require_ios_live_activities_setup', // INFO - ActivityKit configuration

  'require_ios_pasteboard_privacy_handling', // INFO - iOS 16+ clipboard notice
  'require_ios_background_refresh_declaration', // INFO - background fetch setup
  'require_ios_scene_delegate_awareness', // INFO - iOS 13+ multi-window
  'require_ios_review_prompt_frequency', // INFO - StoreKit limits
  'require_macos_window_restoration', // INFO - window state persistence
  'require_ios_certificate_pinning', // INFO - security for sensitive APIs
  'require_ios_biometric_fallback', // INFO - accessibility fallback
  'avoid_ios_misleading_push_notifications', // INFO - App Store compliance

  'prefer_background_sync', // INFO - use BGTaskScheduler for sync
  'require_sync_error_recovery', // INFO - retry failed syncs
  'require_ios_entitlements', // INFO - entitlement detection for features
  'require_ios_launch_storyboard', // INFO - App Store requirement reminder
  'require_ios_version_check', // INFO - version-specific API detection
  'require_ios_focus_mode_awareness', // INFO - Focus Mode interruption levels
  'require_ios_quick_note_awareness', // INFO - NSUserActivity for Quick Note
  'require_macos_entitlements', // INFO - macOS entitlement detection
  // ROADMAP ⭐ Rules - Professional
  'require_bloc_repository_injection', // INFO - DI through constructor for testability
  'avoid_freezed_for_logic_classes', // INFO - Freezed for data, not business logic
  // v2.6.0 rules (ROADMAP_NEXT)
  'prefer_riverpod_auto_dispose', // INFO - memory management
  'avoid_getx_global_navigation', // WARNING - testability
  'require_getx_binding_routes', // INFO - DI lifecycle
  'require_dio_retry_interceptor', // INFO - network resilience
  'prefer_shell_route_shared_layout', // INFO - code reuse
  'require_stateful_shell_route_tabs', // INFO - state preservation
  'prefer_sqflite_singleton', // INFO - connection management
  'require_freezed_json_converter', // INFO - JSON serialization
  'prefer_geolocator_accuracy_appropriate', // INFO - battery management
  'prefer_geolocator_last_known', // INFO - battery optimization
  'require_notification_action_handling', // INFO - notification UX
  'require_finally_cleanup', // INFO - resource cleanup
  'require_di_scope_awareness', // INFO - DI lifecycle
  'require_deep_equality_collections', // WARNING - state comparison
  'avoid_equatable_datetime', // WARNING - flaky equality
  'prefer_unmodifiable_collections', // INFO - immutability
  // NEW v4.1.5 Rules - Professional
  'avoid_static_route_config', // WARNING - static route configs limit testability
  'avoid_firebase_realtime_in_build', // WARNING - Firebase listeners in build
  'avoid_secure_storage_large_data', // INFO - large data not suited for secure storage
  'require_pop_result_type', // INFO - typed navigation results
  'avoid_nested_navigators_misuse', // WARNING - nested navigators need WillPopScope
  'require_deep_link_testing', // INFO - routes should support deep links
  'prefer_intl_message_description', // INFO - Intl.message needs desc for translators
  'avoid_hardcoded_locale_strings', // WARNING - hardcoded strings break i18n
  'avoid_riverpod_navigation', // INFO - navigation belongs in widgets
  'require_drag_alternatives', // INFO - provide buttons for drag operations
  'require_pending_changes_indicator', // INFO - show sync status to users
  // NEW v4.1.6 Rules - Professional
  'require_platform_check', // INFO - platform-specific APIs need checks
  'prefer_iso8601_dates', // INFO - standard date format for APIs
  'require_structured_logging', // INFO - structured logs over concatenation
  // NEW v4.1.7 Rules - Professional
  'require_locale_for_text', // INFO - text formatting needs explicit locale
  'avoid_riverpod_for_network_only', // INFO - overkill for simple network access
  'avoid_large_bloc', // INFO - Blocs with too many handlers
  'avoid_overengineered_bloc_states', // INFO - too many state subclasses
  'avoid_getx_static_context', // WARNING - GetX static context untestable
  'avoid_tight_coupling_with_getx', // INFO - heavy GetX usage
  'require_isolate_for_heavy', // WARNING - heavy computation blocks UI
  'avoid_json_in_main', // INFO - jsonDecode on main thread
  'avoid_encryption_key_in_memory', // INFO - keys in memory can be extracted
  'prefer_lazy_singleton_registration', // INFO - eager singletons slow startup
  'require_cache_key_uniqueness', // INFO - cache keys need stable hashCode
  // v4.14.0 - GitHub issue rules (Professional)
  'require_log_level_for_production', // INFO - guard verbose logs for production
  'require_analytics_event_naming', // INFO - snake_case analytics events
  // Best practices (auto-assigned by severity)
  'avoid_adjacent_strings',
  'avoid_always_null_parameters',
  'avoid_autoplay_audio',
  'avoid_barrel_files',
  'avoid_border_all',
  'avoid_calling_of_in_build',
  'avoid_collapsible_if',
  // 'prefer_no_commented_out_code' moved to stylisticRules (v4.2.0)
  'avoid_complex_arithmetic_expressions',
  'avoid_complex_loop_conditions',
  'avoid_context_in_static_methods',
  'avoid_declaring_call_method',
  'avoid_default_tostring',
  'avoid_digit_separators',
  'avoid_duplicate_constant_values',
  'avoid_duplicate_initializers',
  'avoid_duplicate_string_literals_pair',
  'avoid_empty_setstate', // stylistic: moved from recommended (v4.12.4)
  'avoid_excessive_bottom_nav_items',
  'avoid_excessive_expressions',
  'avoid_explicit_pattern_field_name',
  'avoid_extensions_on_records',
  'avoid_find_all',
  'avoid_fitted_box_for_text',
  'avoid_fixed_dimensions',
  'avoid_font_weight_as_number',
  'avoid_form_in_alert_dialog',
  'avoid_form_without_unfocus',
  'avoid_function_type_in_records',
  'avoid_hardcoded_colors',
  'avoid_hardcoded_feature_flags',
  'avoid_icon_size_override',
  'avoid_identical_exception_handling_blocks',
  'avoid_if_with_many_branches',
  'avoid_image_repeat',
  'avoid_image_without_cache',
  'avoid_immediately_invoked_functions',
  'avoid_incomplete_copy_with',
  'avoid_inconsistent_digit_separators',
  // Note: prefer_inferred_type_arguments is stylistic (opt-in only, conflicts with prefer_explicit_type_arguments)
  'avoid_inverted_boolean_checks',
  'avoid_ios_debug_code_in_release',
  'avoid_late_keyword',
  'avoid_local_functions',
  'avoid_long_length_files',
  'avoid_long_length_test_files',
  'avoid_long_records',
  'avoid_missing_image_alt',
  'avoid_mixing_named_and_positional_fields',
  'avoid_multi_assignment',
  'avoid_negated_conditions',
  'avoid_negations_in_equality_checks',
  'avoid_nested_conditional_expressions',
  'avoid_nested_extension_types',
  'avoid_nested_records',
  'avoid_nested_shorthands',
  'avoid_nested_switch_expressions',
  'avoid_nested_switches',
  'avoid_nested_try',
  'avoid_non_ascii_symbols',
  'avoid_non_empty_constructor_bodies',
  'avoid_nullable_tostring',
  'avoid_one_field_records',
  'avoid_over_fetching',
  'avoid_passing_default_values',
  'avoid_positional_record_field_access',
  'avoid_raw_keyboard_listener',
  'avoid_redundant_else',
  'avoid_redundant_positional_field_name',
  'avoid_redundant_pragma_inline',
  'avoid_returning_cascades',
  'avoid_returning_void',
  'avoid_service_locator_overuse',
  'avoid_single_field_destructuring',
  'avoid_singleton_pattern',
  'avoid_sized_box_expand',
  'avoid_slow_collection_methods',
  'avoid_stateful_widget_in_list',
  'avoid_text_span_in_build',
  'avoid_throw_objects_without_tostring',
  'avoid_top_level_members_in_tests',
  'avoid_unassigned_fields',
  'avoid_unnecessary_block',
  'avoid_unnecessary_call',
  'avoid_unnecessary_collections',
  'avoid_unnecessary_compare_to',
  'avoid_unnecessary_constructor',
  'avoid_unnecessary_continue',
  'avoid_unnecessary_digit_separators',
  'avoid_unnecessary_enum_arguments',
  'avoid_unnecessary_enum_prefix',
  'avoid_unnecessary_extends',
  'avoid_unnecessary_getter',
  'avoid_unnecessary_if',
  'avoid_unnecessary_late_fields',
  'avoid_unnecessary_length_check',
  'avoid_unnecessary_local_late',
  'avoid_unnecessary_local_variable',
  'avoid_unnecessary_negations',
  'avoid_unnecessary_nullable_fields',
  'avoid_unnecessary_nullable_parameters',
  'avoid_unnecessary_nullable_return_type',
  'avoid_unnecessary_overrides',
  'avoid_unnecessary_patterns',
  'avoid_unnecessary_return',
  'avoid_unnecessary_super',
  'avoid_unused_after_null_check',
  'avoid_unused_assignment',
  'avoid_unused_callback_parameters',
  'avoid_vague_test_descriptions',
  'avoid_widget_creation_in_loop',
  // 'binary_expression_operand_order' moved to stylisticRules (opinionated)
  // 'double_literal_format' moved to stylisticRules (opinionated)
  // 'enforce_parameters_ordering' moved to stylisticRules (opinionated)
  // 'enum_constants_ordering' moved to stylisticRules (opinionated)
  'function_always_returns_same_value',
  'limit_max_imports',
  // 'map_keys_ordering' moved to stylisticRules (opinionated)
  'match_base_class_default_value',
  'match_getter_setter_field_names',
  'match_lib_folder_structure',
  'match_positional_field_names_on_assignment',
  'missing_use_result_annotation',
  'move_records_to_typedefs',
  'move_variable_outside_iteration',
  'no_equal_switch_case',
  'no_equal_switch_expression_cases',
  'no_magic_number',
  'no_magic_string',
  'no_object_declaration',
  'pass_optional_argument',
  'prefer_abstract_final_static_class',
  'prefer_add_all',
  // cspell:ignore addall
  // 'prefer_addall_over_spread' moved to stylisticRules (opinionated)
  'prefer_addition_subtraction_assignments',
  // 'prefer_all_named_parameters' moved to stylisticRules (opinionated)
  'prefer_any_or_every',
  // 'prefer_arrow_functions' moved to stylisticRules (opinionated)
  'prefer_async_await',
  // 'prefer_async_only_when_awaiting' removed (duplicate of avoid_redundant_async)
  'prefer_audio_session_config',
  // 'prefer_await_over_then' moved to stylisticRules (opinionated)
  // 'prefer_blank_line_after_declarations' moved to stylisticRules (opinionated)
  // 'prefer_blank_line_before_case' moved to stylisticRules (opinionated)
  // 'prefer_blank_line_before_constructor' moved to stylisticRules (opinionated)
  // 'prefer_blank_line_before_method' moved to stylisticRules (opinionated)
  // 'prefer_blank_line_before_return' moved to stylisticRules (opinionated)
  // 'prefer_blank_lines_between_members' moved to stylisticRules (opinionated)
  // 'prefer_boolean_prefixes_for_locals' moved to stylisticRules (opinionated)
  // 'prefer_borderradius_circular' moved to stylisticRules (opinionated)
  'prefer_both_inlining_annotations',
  'prefer_bytes_builder',
  'prefer_cached_network_image',
  // 'prefer_camel_case_method_names' moved to stylisticRules (opinionated)
  'prefer_camera_resolution_selection',
  // 'prefer_cascade_over_chained' moved to stylisticRules (opinionated)
  // 'prefer_chained_over_cascade' moved to stylisticRules (opinionated)
  // 'prefer_class_over_record_return' moved to stylisticRules (opinionated)
  // 'prefer_collection_if_over_ternary' moved to stylisticRules (opinionated)
  'prefer_color_scheme_from_seed',
  'prefer_commenting_analyzer_ignores',
  'prefer_commenting_future_delayed',
  // 'prefer_compact_class_members' moved to stylisticRules (opinionated)
  // 'prefer_compact_declarations' moved to stylisticRules (opinionated)
  'prefer_compound_assignment_operators',
  // 'prefer_concatenation_over_interpolation' moved to stylisticRules (opinionated)
  // 'prefer_concise_variable_names' moved to stylisticRules (opinionated)
  // 'prefer_conditional_expressions' moved to stylisticRules (opinionated)
  'prefer_const_border_radius',
  'prefer_const_string_list',
  'prefer_const_widgets',
  // 'prefer_constructor_assertion' moved to stylisticRules (opinionated)
  // 'prefer_constructor_body_assignment' moved to stylisticRules (opinionated)
  // 'prefer_container_over_sizedbox' moved to stylisticRules (opinionated)
  'prefer_context_selector',
  // 'prefer_correct_callback_field_name' moved to stylisticRules (opinionated)
  'prefer_correct_edge_insets_constructor',
  'prefer_correct_error_name',
  // 'prefer_correct_handler_name' moved to stylisticRules (opinionated)
  'prefer_correct_identifier_length',
  // 'prefer_correct_setter_parameter_name' moved to stylisticRules (opinionated)
  'prefer_correct_switch_length',
  'prefer_correct_test_file_name',
  'prefer_cupertino_for_ios',
  'prefer_cupertino_for_ios_feel',
  // 'prefer_curly_apostrophe' moved to stylisticRules (opinionated)
  'prefer_declaring_const_constructor',
  'prefer_dedicated_media_query_method',
  // 'prefer_default_enum_case' moved to stylisticRules (opinionated)
  // 'prefer_descriptive_bool_names' moved to stylisticRules (opinionated)
  // 'prefer_descriptive_bool_names_strict' moved to stylisticRules (opinionated)
  'prefer_descriptive_test_name',
  // 'prefer_descriptive_variable_names' moved to stylisticRules (opinionated)
  'prefer_digit_separators',
  'prefer_dio_transformer',
  // 'prefer_doc_comments_over_regular' moved to stylisticRules (opinionated)
  // 'prefer_doc_curly_apostrophe' moved to stylisticRules (conflicting pair)
  // 'prefer_doc_straight_apostrophe' moved to stylisticRules (conflicting pair)
  // 'prefer_double_quotes' moved to stylisticRules (conflicting pair)
  // 'prefer_dynamic_over_object' moved to stylisticRules (opinionated)
  // 'prefer_edgeinsets_only' moved to stylisticRules (opinionated)
  // 'prefer_edgeinsets_symmetric' moved to stylisticRules (opinionated)
  'prefer_enhanced_enums',
  'prefer_enums_by_name',
  // 'prefer_exhaustive_enums' moved to stylisticRules (opinionated)
  // 'prefer_expanded_over_flexible' moved to stylisticRules (opinionated)
  // 'prefer_expect_over_assert_in_tests' moved to stylisticRules (opinionated)
  // 'prefer_explicit_boolean_comparison' moved to stylisticRules (opinionated)
  // 'prefer_explicit_colors' moved to stylisticRules (opinionated)
  'prefer_explicit_function_type',
  // 'prefer_explicit_null_assignment' moved to stylisticRules (opinionated)
  'prefer_explicit_parameter_names',
  // 'prefer_explicit_this' moved to stylisticRules (opinionated)
  // 'prefer_explicit_types' moved to stylisticRules (opinionated)
  'prefer_extracting_callbacks',
  'prefer_extracting_function_callbacks',
  // 'prefer_factory_for_validation' moved to stylisticRules (opinionated)
  // 'prefer_fake_over_mock' moved to stylisticRules (opinionated)
  // 'prefer_fields_before_methods' moved to stylisticRules (opinionated)
  // 'prefer_fixme_format' moved to stylisticRules (opinionated)
  // 'prefer_flexible_over_expanded' moved to stylisticRules (opinionated)
  // 'prefer_for_in' moved to stylisticRules (opinionated)
  // 'prefer_future_void_function_over_async_callback' moved to stylisticRules (opinionated)
  // 'prefer_generic_exception' moved to stylisticRules (opinionated)
  // 'prefer_getter_over_method' moved to stylisticRules (opinionated)
  // 'prefer_given_when_then_comments' moved to stylisticRules (opinionated)
  // 'prefer_grouped_by_purpose' moved to stylisticRules (opinionated)
  // 'prefer_grouped_expectations' moved to stylisticRules (opinionated)
  // 'prefer_guard_clauses' moved to stylisticRules (opinionated)
  // 'prefer_if_null_over_ternary' moved to stylisticRules (opinionated)
  // 'prefer_immediate_return' moved to stylisticRules (opinionated)
  // 'prefer_implicit_boolean_comparison' moved to stylisticRules (opinionated)
  // 'prefer_initializing_formals' moved to stylisticRules (opinionated)
  // 'prefer_inline_callbacks' moved to stylisticRules (opinionated)
  // 'prefer_instance_members_first' moved to stylisticRules (conflicting pair)
  // 'prefer_interpolation_over_concatenation' moved to stylisticRules (opinionated)
  'prefer_ios_app_intents_framework',
  'prefer_ios_context_menu',
  'prefer_ios_handoff_support',
  'prefer_ios_haptic_feedback',
  'prefer_ios_spotlight_indexing',
  'prefer_iterable_of',
  'prefer_keyboard_shortcuts',
  // 'prefer_keys_with_lookup' moved to stylisticRules (opinionated)
  // 'prefer_late_over_nullable' moved to stylisticRules (opinionated)
  'prefer_list_contains',
  // 'prefer_lower_camel_case_constants' moved to stylisticRules (opinionated)
  'prefer_macos_keyboard_shortcuts',
  'prefer_macos_menu_bar_integration',
  // 'prefer_map_entries_iteration' moved to stylisticRules (opinionated)
  'prefer_match_file_name',
  // 'prefer_material_theme_colors' moved to stylisticRules (opinionated)
  // 'prefer_methods_before_fields' moved to stylisticRules (opinionated)
  'prefer_moving_to_variable',
  'prefer_named_boolean_parameters',
  'prefer_named_extensions',
  'prefer_named_parameters',
  'prefer_native_file_dialogs',
  // 'prefer_no_blank_line_before_return' moved to stylisticRules (opinionated)
  // 'prefer_no_blank_line_inside_blocks' moved to stylisticRules (opinionated)
  // 'prefer_null_aware_assignment' moved to stylisticRules (opinionated)
  'prefer_null_aware_elements',
  'prefer_null_aware_spread',
  // 'prefer_nullable_over_late' moved to stylisticRules (opinionated)
  // 'prefer_object_over_dynamic' moved to stylisticRules (opinionated)
  // 'prefer_on_over_catch' moved to stylisticRules (opinionated)
  // 'prefer_one_widget_per_file' moved to stylisticRules (opinionated)
  'prefer_parentheses_with_if_null',
  'prefer_pattern_destructuring',
  // 'prefer_period_after_doc' moved to stylisticRules (opinionated)
  'prefer_physics_simulation',
  // 'prefer_positive_conditions_first' moved to stylisticRules (opinionated)
  'prefer_prefixed_global_constants',
  'prefer_private_extension_type_field',
  // 'prefer_private_members_first' moved to stylisticRules (conflicting pair)
  // 'prefer_private_underscore_prefix' moved to stylisticRules (opinionated)
  'prefer_proxy_provider',
  'prefer_public_exception_classes',
  // 'prefer_public_members_first' moved to stylisticRules (conflicting pair)
  // 'prefer_pushing_conditional_expressions' moved to stylisticRules (opinionated)
  // 'prefer_required_before_optional' moved to stylisticRules (opinionated)
  // 'prefer_returning_condition' moved to stylisticRules (opinionated)
  // 'prefer_returning_conditionals' moved to stylisticRules (opinionated)
  // 'prefer_returning_shorthands' moved to stylisticRules (opinionated)
  'prefer_rich_text_for_complex',
  // 'prefer_richtext_over_text_rich' moved to stylisticRules (opinionated)
  // 'prefer_screaming_case_constants' moved to stylisticRules (opinionated)
  'prefer_sealed_events',
  'prefer_selectable_text',
  // 'prefer_self_documenting_tests' moved to stylisticRules (opinionated)
  // 'prefer_sentence_case_comments' moved to stylisticRules (opinionated)
  'prefer_set_for_lookup',
  'prefer_shorthands_with_constructors',
  'prefer_shorthands_with_enums',
  'prefer_shorthands_with_static_fields',
  'prefer_simpler_patterns_null_check',
  'prefer_single_assertion',
  // 'prefer_single_blank_line_max' moved to stylisticRules (opinionated)
  'prefer_single_declaration_per_file',
  // 'prefer_single_expectation_per_test' moved to stylisticRules (opinionated)
  // 'prefer_single_quotes' moved to stylisticRules (conflicting pair)
  'prefer_single_widget_per_file',
  // 'prefer_sizedbox_over_container' moved to stylisticRules (opinionated)
  // 'prefer_sliver_prefix' moved to stylisticRules (opinionated)
  // 'prefer_snake_case_files' moved to stylisticRules (opinionated)
  // 'prefer_specific_exceptions' moved to stylisticRules (opinionated)
  // 'prefer_spread_over_addall' moved to stylisticRules (opinionated)
  'prefer_static_class',
  'prefer_static_const_widgets',
  // 'prefer_static_members_first' moved to stylisticRules (conflicting pair)
  // 'prefer_straight_apostrophe' moved to stylisticRules (conflicting pair)
  'prefer_streaming_response',
  // 'prefer_super_parameters' moved to stylisticRules (opinionated)
  'prefer_switch_expression',
  // 'prefer_switch_statement' moved to stylisticRules (opinionated)
  'prefer_switch_with_enums',
  'prefer_switch_with_sealed_classes',
  // 'prefer_sync_over_async_where_possible' moved to stylisticRules (opinionated)
  // 'prefer_ternary_over_collection_if' moved to stylisticRules (opinionated)
  // 'prefer_ternary_over_if_null' moved to stylisticRules (opinionated)
  // 'prefer_test_name_descriptive' moved to stylisticRules (opinionated)
  // 'prefer_test_name_should_when' moved to stylisticRules (opinionated)
  'prefer_text_rich',
  // 'prefer_text_rich_over_richtext' moved to stylisticRules (opinionated)
  // 'prefer_then_over_await' moved to stylisticRules (opinionated)
  // 'prefer_todo_format' moved to stylisticRules (opinionated)
  // 'prefer_trailing_comma' moved to stylisticRules (opinionated)
  // 'prefer_trailing_comma_always' moved to stylisticRules (opinionated)
  // 'prefer_trailing_underscore_for_unused' moved to stylisticRules (opinionated)
  // 'prefer_type_over_var' moved to stylisticRules (conflicts with prefer_var_over_explicit_type)
  'prefer_typedef_for_callbacks',
  'prefer_utc_datetimes',
  // 'prefer_var_over_explicit_type' moved to stylisticRules (opinionated)
  'prefer_visible_for_testing_on_members',
  'prefer_when_guard_over_if',
  // 'prefer_wheretype_over_where_is' moved to stylisticRules (opinionated)
  // 'prefer_widget_methods_over_classes' moved to stylisticRules (opinionated)
  'prefer_wildcard_pattern',
  'require_extend_equatable',
  'require_form_restoration',
  'require_ios_accessibility_labels',
  'require_ios_age_rating_consideration',
  'require_ios_promotion_display_support',
  'require_ios_voiceover_gesture_compatibility',
  'require_multi_provider',
  'require_overflow_box_rationale',
  'require_pump_after_interaction',
  'require_response_caching',
  'require_scroll_tests',
  'require_text_input_tests',
  'require_theme_color_from_scheme',
  'require_update_callback',
  // 'unnecessary_trailing_comma' moved to stylisticRules (opinionated)
  'use_existing_destructuring',
  'use_existing_variable',

  // =========================================================================
  // v4.2.0 ROADMAP ⭐ Rules - Professional
  // =========================================================================
  'avoid_android_task_affinity_default', // INFO - taskAffinity should be explicit
  'require_android_backup_rules', // INFO - Android backup rules should be defined
  'prefer_notification_grouping', // INFO - notifications should be grouped
  'require_hive_migration_strategy', // INFO - Hive migrations need strategy
  'avoid_stream_sync_events', // WARNING - streams shouldn't emit sync events
  'avoid_sequential_awaits', // INFO - use Future.wait for parallel operations
  'prefer_streaming_for_large_files', // INFO - stream large files instead of loading all
  'prefer_focus_traversal_order', // INFO - define focus traversal order
  'avoid_loading_flash', // INFO - avoid flash of loading content
  'avoid_animation_in_large_list', // WARNING - animations in large lists hurt performance
  'require_json_schema_validation', // INFO - validate JSON against schema
  'prefer_typed_prefs_wrapper', // INFO - wrap SharedPreferences with typed accessor
  'require_geolocator_battery_awareness', // WARNING - location tracking drains battery
  // --- Restored orphan rules (high impact) ---
  'always_remove_getx_listener',
  'avoid_cached_isar_stream',
  'avoid_dio_debug_print_production',
  'avoid_dynamic_json_access',
  'avoid_getx_rx_inside_build',
  'avoid_image_picker_large_files',
  'avoid_isar_schema_breaking_changes',
  'avoid_mutable_rx_variables',
  'avoid_obs_outside_controller',
  'avoid_provider_in_init_state',
  'avoid_static_state',
  'dispose_getx_fields',
  'prefer_bloc_listener_for_side_effects',
  'prefer_getx_builder',
  'prefer_maybe_pop',
  'prefer_webview_javascript_disabled',
  'require_enum_unknown_value',
  'require_file_handle_close',
  'require_geolocator_timeout',
  'require_getx_controller_dispose',
  'require_image_error_fallback',
  'require_image_picker_error_handling',
  'require_image_picker_result_handling',
  'require_isar_close_on_dispose',
  'require_isar_inspector_debug_only',
  'require_isar_links_load',
  'require_notification_initialize_per_platform',
  'require_notification_permission_android13',
  'require_permission_denied_handling',
  'require_permission_status_check',
  'require_sqflite_migration',
  'require_url_launcher_error_handling',
  'require_webview_error_handling',
  'require_webview_navigation_delegate',

  // Windows/Linux platform rules (Professional)
  'require_windows_single_instance_check', // INFO - desktop apps need single-instance guard
  'avoid_max_path_risk', // INFO - deeply nested paths hit MAX_PATH on Windows
  'prefer_xdg_directory_convention', // INFO - use XDG base directories on Linux
  'require_linux_font_fallback', // INFO - platform fonts need fallback on Linux
  // ROADMAP ⭐ Rules - Professional (new batch)
  'avoid_datetime_comparison_without_precision', // INFO - DateTime == fails on microseconds
  'avoid_getx_static_get', // WARNING - Get.find() hides dependencies
  'require_navigation_result_handling', // INFO - Navigator.push result ignored
  'require_semantic_colors', // INFO - name colors by purpose not appearance
  // v4.15.0 - ROADMAP ⭐ Rules (Professional)
  'prefer_semantics_container', // INFO - Semantics needs container: true for groups
  'avoid_image_picker_quick_succession', // WARNING - pickImage without debounce guard
  'prefer_input_formatters', // INFO - numeric fields need TextInputFormatter
  'prefer_go_router_redirect', // INFO - GoRouter needs redirect for auth
  'prefer_permission_request_in_context', // INFO - don't request perms in main()
  'avoid_shared_prefs_large_data', // WARNING - don't store JSON in SharedPrefs
  'prefer_geocoding_cache', // INFO - cache reverse geocoding results
  'prefer_oauth_pkce', // INFO - OAuth needs PKCE for mobile
  'avoid_continuous_location_updates', // WARNING - GPS stream needs distance filter
  'prefer_grace_period_handling', // INFO - handle IAP billing grace period
  'require_cached_image_device_pixel_ratio', // INFO - use DPR for cached images
  'prefer_foreground_service_android', // INFO - use foreground service for bg work
  'prefer_sliverfillremaining_for_empty', // INFO - empty state in CustomScrollView
  'avoid_infinite_scroll_duplicate_requests', // WARNING - loading guard for scroll
  'prefer_infinite_scroll_preload', // INFO - preload at 80% scroll
  'prefer_use_callback', // INFO - memoize callbacks in HookWidget
  'require_stepper_state_management', // INFO - preserve Stepper form state
  // v4.15.0 - ROADMAP ⭐ Rules (Professional) - batch 2
  'prefer_optimistic_updates', // INFO - setState before await, not after
  'avoid_full_sync_on_every_launch', // WARNING - use delta sync not getAll
  'require_session_timeout', // INFO - auth needs session expiry
  // v5.1.0 - New lint rules (Professional)
  'avoid_clip_during_animation', // WARNING - clip inside animation = janky
  'avoid_auto_route_context_navigation', // WARNING - use typed routes
  'avoid_auto_route_keep_history_misuse', // WARNING - replaceAll clears stack
  'avoid_accessing_other_classes_private_members', // WARNING - encapsulation
  'avoid_closure_capture_leaks', // WARNING - setState in Timer w/o mounted
  'avoid_behavior_subject_last_value', // WARNING - .value on closed subject
  'avoid_cache_stampede', // WARNING - cache miss without dedup
  'avoid_deep_nesting', // WARNING - deeply nested code blocks
  'avoid_high_cyclomatic_complexity', // WARNING - high complexity
  'avoid_collection_mutating_methods', // WARNING - mutating in setState
  'avoid_equatable_nested_equality', // WARNING - mutable collections in props
  'avoid_getx_rx_nested_obs', // WARNING - nested Rx observables
  'avoid_freezed_any_map_issue', // WARNING - missing anyMap: true
  'avoid_hive_datetime_local', // WARNING - local DateTime in Hive
  'avoid_hive_type_modification', // WARNING - duplicate HiveField indices
  'avoid_hive_large_single_entry', // WARNING - large single Hive entry
  'avoid_firebase_user_data_in_auth', // WARNING - too many custom claims
  'require_firebase_app_check_production', // WARNING - missing App Check
  // v5.1.0 - Batch 3 (Professional)
  'avoid_entitlement_without_server', // WARNING - client-only IAP verification
  'avoid_expensive_did_change_dependencies', // WARNING - heavy work in didChangeDependencies
  'avoid_webview_cors_issues', // WARNING - CORS bypass in WebView settings
  'avoid_form_validation_on_change', // WARNING - validate() in onChanged
  'avoid_multiple_animation_controllers', // WARNING - 3+ AnimationControllers
  'avoid_permission_request_loop', // WARNING - Permission.request() in loop
};

/// Rules that are only included in the comprehensive tier (not in professional).
/// Comprehensive tier rules - stricter patterns, optimization hints, edge cases.
/// Helpful but not critical. For quality-obsessed teams.
const Set<String> comprehensiveOnlyRules = <String>{
  // Import sorting
  'prefer_sorted_imports', // alphabetical import sorting within groups
  // Performance micro-optimizations (moved from Professional)
  'prefer_item_extent', // scroll performance hint
  'prefer_prototype_item', // consistent sizing optimization
  'require_add_automatic_keep_alives_off', // memory efficiency
  'prefer_http_connection_reuse', // connection reuse
  'avoid_redundant_requests', // resource efficiency
  'prefer_coarse_location_when_sufficient', // battery/precision tradeoff
  'prefer_image_precache', // image loading optimization
  'prefer_sliver_list_delegate', // list optimization
  'require_repaint_boundary', // paint optimization
  'prefer_ble_mtu_negotiation', // BLE transfer efficiency
  'prefer_lazy_box_for_large', // Hive lazy loading
  // Drift database (Comprehensive)
  'avoid_drift_query_in_migration', // WARNING - high-level API in onUpgrade
  'require_drift_schema_version_bump', // INFO - schema changes without version bump
  'avoid_drift_foreign_key_in_migration', // INFO - PRAGMA in migration transaction
  'require_drift_reads_from', // INFO - customSelect.watch() without readsFrom
  'avoid_drift_unsafe_web_storage', // INFO - unsafeIndexedDb not multi-tab safe
  'avoid_drift_close_streams_in_tests', // INFO - missing closeStreamsSynchronously
  'avoid_drift_nullable_converter_mismatch', // INFO - both-nullable TypeConverter
  'prefer_geolocator_distance_filter', // battery optimization
  'prefer_inherited_widget_cache', // cache optimization
  'prefer_layout_builder_over_media_query', // rebuild optimization
  'require_list_preallocate', // list allocation
  'prefer_compute_over_isolate_run', // isolate efficiency
  'prefer_itemextent_when_known', // scroll optimization
  'prefer_cached_paint_objects', // paint object reuse
  'avoid_excessive_widget_depth', // widget tree depth
  'avoid_image_rebuild_on_scroll', // scroll performance
  // Strict immutability patterns (moved from Professional)
  'prefer_immutable_provider_arguments',
  'prefer_immutable_bloc_events',
  'prefer_immutable_bloc_state',
  'prefer_sealed_bloc_events',
  'prefer_sealed_bloc_state',
  'prefer_immutable_selector_value',

  // Type strictness (moved from Professional)
  'prefer_constrained_generics',
  // Note: prefer_explicit_type_arguments is stylistic (opt-in only, conflicts with prefer_inferred_type_arguments)
  'prefer_typed_data',
  'prefer_typedefs_for_callbacks',

  // Naming suffix conventions (moved from Professional)
  // 'prefer_bloc_event_suffix' moved to stylisticRules (opinionated)
  // 'prefer_bloc_state_suffix' moved to stylisticRules (opinionated)
  // 'prefer_use_prefix' moved to stylisticRules (opinionated)

  // Documentation extras (moved from Professional)
  'require_covariant_documentation',
  'require_futureor_documentation',
  'require_async_error_documentation',

  // Testing extras (moved from Professional)
  'require_animation_tests',
  // 'prefer_test_data_builder' moved to stylisticRules (opinionated)
  'prefer_test_variant',
  'require_accessibility_tests',
  'prefer_fake_platform', // platform fakes in tests
  // Animation polish (moved from Professional)
  'require_staggered_animation_delays',

  // Strict patterns (moved from Professional)
  'prefer_equatable_mixin',
  'prefer_void_callback',
  'prefer_symbol_over_key',
  'prefer_notifier_over_state',
  'prefer_provider_extensions',
  'prefer_redirecting_superclass_constructor',

  // Kept from original Comprehensive
  'prefer_element_rebuild', // conditional returns destroy Elements
  'avoid_finalizer_misuse', // Finalizers add GC overhead
  'require_test_documentation', // complex tests need comments
  // --- Restored orphan rules (medium + low impact) ---
  'avoid_cached_image_in_build',
  'avoid_dio_without_base_url',
  'avoid_getx_global_state',
  'avoid_isar_embedded_large_objects',
  'avoid_isar_float_equality_queries',
  'avoid_isar_string_contains_without_index',
  'avoid_isar_web_limitations',
  'avoid_late_without_guarantee',
  'avoid_nested_try_statements',
  'avoid_non_null_assertion',
  'avoid_sqflite_read_all_columns',
  'avoid_type_casts',
  'avoid_unremovable_callbacks_in_listeners',
  'avoid_unsafe_setstate',
  'no_magic_number_in_tests',
  'no_magic_string_in_tests',
  'prefer_bloc_transform',
  'prefer_cached_image_fade_animation',
  'prefer_change_notifier_proxy',
  'prefer_constructor_injection',
  'prefer_context_read_in_callbacks',
  'prefer_cubit_for_simple_state',
  'prefer_dio_base_options',
  'prefer_equatable_stringify',
  'prefer_freezed_default_values',
  'prefer_future_wait',
  'prefer_go_router_redirect_auth',
  'prefer_image_picker_request_full_metadata',
  'prefer_immutable_annotation',
  'prefer_isar_async_writes',
  'prefer_isar_batch_operations',
  'prefer_isar_composite_index',
  'prefer_isar_index_for_queries',
  'prefer_isar_lazy_links',
  'prefer_isar_query_stream',
  'prefer_selector_over_consumer',
  'prefer_selector_widget',
  'require_animated_builder_child',
  'require_bloc_consumer_when_both',
  'require_bloc_error_state',
  'require_bloc_event_sealed',
  'require_bloc_loading_state',
  'require_bloc_repository_abstraction',
  'require_dio_singleton',
  'require_freezed_explicit_json',
  'require_getx_binding',
  'require_go_router_typed_params',
  'require_hive_type_id_management',
  'require_image_picker_source_choice',
  'require_intl_locale_initialization',
  'require_notification_timezone_awareness',
  'require_permission_rationale',
  'require_physics_for_nested_scroll',
  'require_rethrow_preserve_stack',
  'require_text_form_field_in_form',
  'require_url_launcher_mode',
  'require_webview_progress_indicator',

  // v4.15.0 - ROADMAP ⭐ Rules (Comprehensive)
  'avoid_redundant_semantics', // INFO - Semantics wrapping Image with semanticLabel
};

/// Pedantic tier rules - pedantic, highly opinionated rules.
/// Rules most teams would find excessive. For greenfield projects.
const Set<String> pedanticOnlyRules = <String>{
  // File length (very strict thresholds - 200 lines for production, 400 for tests)
  'prefer_small_length_files', // 200 line limit
  'prefer_small_length_test_files', // 400 line limit for tests
  // Architecture preferences (very opinionated)
  'prefer_feature_folder_structure', // folder organization preference
  'prefer_custom_single_child_layout', // CustomSingleChildLayout for positioning
  // Micro-optimizations (diminishing returns)
  'avoid_object_creation_in_hot_loops', // loop allocation pedantry
  'prefer_specific_numeric_types', // int vs num pedantry
  // Documentation pedantry
  // 'format_comment_style' moved to stylisticRules (opinionated)
  'prefer_providing_intl_description', // i18n descriptions
  'prefer_providing_intl_examples', // i18n examples
  // Very strict patterns
  'avoid_returning_widgets', // no widget helper methods
  'avoid_nullable_widget_methods', // no nullable widget returns
  // Test pedantry
  'avoid_duplicate_test_assertions', // no repeated assertions
};

/// Returns the set of rule names for a given tier.
Set<String> getRulesForTier(String tier) {
  switch (tier) {
    case 'stylistic':
      return stylisticRules;
    case 'essential':
      return essentialRules;
    case 'recommended':
      // recommended = essential + recommendedOnly
      return essentialRules.union(recommendedOnlyRules);
    case 'professional':
      // professional = recommended + professionalOnly
      return essentialRules
          .union(recommendedOnlyRules)
          .union(professionalOnlyRules);
    case 'comprehensive':
      // comprehensive = professional + comprehensiveOnly
      return essentialRules
          .union(recommendedOnlyRules)
          .union(professionalOnlyRules)
          .union(comprehensiveOnlyRules);
    case 'pedantic':
      // pedantic = all rules
      return essentialRules
          .union(recommendedOnlyRules)
          .union(professionalOnlyRules)
          .union(comprehensiveOnlyRules)
          .union(pedanticOnlyRules);
    default:
      // fallback to essential
      return essentialRules;
  }
}

/// Returns the complete set of all rule names defined across all tiers.
///
/// Includes all tier rules plus stylistic rules. Used for validation
/// to ensure plugin rules match tier definitions.
Set<String> getAllDefinedRules() {
  return essentialRules
      .union(recommendedOnlyRules)
      .union(professionalOnlyRules)
      .union(comprehensiveOnlyRules)
      .union(pedanticOnlyRules)
      .union(stylisticRules);
}

// =========================================================================
// PLATFORM RULE SETS
// =========================================================================
// Rules specific to each target platform. Orthogonal to tiers.
//
// A rule can appear in multiple platform sets (e.g., Apple Sign In is both
// iOS and macOS). A rule is disabled only when ALL its platforms are disabled.
//
// General cross-platform rules (require_platform_check, etc.) are NOT in
// any platform set -- they remain always-on regardless of platform config.
// =========================================================================

/// Rules specific to the iOS platform.
const Set<String> iosPlatformRules = <String>{
  // Essential
  'require_https_for_ios',
  'require_ios_permission_description',
  'require_ios_privacy_manifest',
  'require_ios_app_tracking_transparency',
  'require_ios_face_id_usage_description',
  'avoid_ios_in_app_browser_for_auth',
  'require_ios_local_notification_permission',
  'require_ios_healthkit_authorization',
  'require_ios_receipt_validation',
  'require_ios_data_protection',
  'require_ios_keychain_for_credentials',
  'avoid_long_running_isolates', // iOS kills isolates after 30s
  // Recommended
  'prefer_ios_safe_area',
  'avoid_ios_hardcoded_status_bar',
  'avoid_ios_13_deprecations',
  'avoid_ios_simulator_only_code',
  'require_ios_minimum_version_check',
  'require_ios_photo_library_add_usage',
  'require_ios_app_review_prompt_timing',
  'require_ios_push_notification_capability',
  'avoid_ios_hardcoded_device_model',
  'require_ios_app_group_capability',
  'avoid_ios_continuous_location_tracking',
  'require_app_lifecycle_handling',
  'require_ios_nfc_capability_check',
  'require_ios_callkit_integration',
  'require_ios_photo_library_limited_access',
  'require_ios_method_channel_cleanup',
  'avoid_ios_force_unwrap_in_callbacks',
  'require_ios_deployment_target_consistency',
  'require_ios_dynamic_island_safe_zones',
  'require_ios_low_power_mode_handling',
  'require_ios_accessibility_large_text',
  'avoid_ios_hardcoded_keyboard_height',
  'require_ios_multitasking_support',
  'avoid_ios_battery_drain_patterns',
  'avoid_ios_wifi_only_assumption',
  'require_image_picker_permission_ios',
  'require_permission_plist_ios',
  'require_url_launcher_schemes_ios',

  // Professional
  'prefer_ios_storekit2',
  'require_ios_background_mode',
  'avoid_ios_deprecated_uikit',
  'require_ios_keychain_accessibility',
  'avoid_ios_hardcoded_bundle_id',
  'require_ios_ats_exception_documentation',
  'require_ios_siri_intent_definition',
  'require_ios_widget_extension_capability',
  'require_ios_database_conflict_resolution',
  'require_ios_background_audio_capability',
  'require_ios_app_clip_size_limit',
  'require_ios_keychain_sync_awareness',
  'require_ios_share_sheet_uti_declaration',
  'require_ios_icloud_kvstore_limitations',
  'require_ios_orientation_handling',
  'require_ios_universal_links_domain_matching',
  'require_ios_carplay_setup',
  'require_ios_live_activities_setup',
  'require_ios_pasteboard_privacy_handling',
  'require_ios_background_refresh_declaration',
  'require_ios_scene_delegate_awareness',
  'require_ios_review_prompt_frequency',
  'require_ios_certificate_pinning',
  'require_ios_biometric_fallback',
  'avoid_ios_misleading_push_notifications',
  'require_ios_entitlements',
  'require_ios_launch_storyboard',
  'require_ios_version_check',
  'require_ios_focus_mode_awareness',
  'require_ios_quick_note_awareness',
  'avoid_ios_debug_code_in_release',
  'prefer_ios_app_intents_framework',
  'prefer_ios_context_menu',
  'prefer_ios_handoff_support',
  'prefer_ios_haptic_feedback',
  'prefer_ios_spotlight_indexing',
  'require_ios_accessibility_labels',
  'require_ios_age_rating_consideration',
  'require_ios_promotion_display_support',
  'require_ios_voiceover_gesture_compatibility',
  'prefer_cupertino_for_ios',
  'prefer_cupertino_for_ios_feel',
};

/// Rules specific to the Android platform.
const Set<String> androidPlatformRules = <String>{
  // Essential
  'require_notification_channel_android',
  'require_android_permission_request',
  'prefer_pending_intent_flags',
  'avoid_android_cleartext_traffic',

  // Recommended
  'require_android_12_splash',
  'require_image_picker_permission_android',
  'require_permission_manifest_android',
  'require_url_launcher_queries_android',
  'require_notification_permission_android13',

  // Professional
  'avoid_android_task_affinity_default',
  'require_android_backup_rules',
};

/// Rules specific to the macOS platform.
const Set<String> macosPlatformRules = <String>{
  // Essential
  'avoid_macos_catalyst_unsupported_apis',
  'require_macos_notarization_ready',

  // Recommended
  'require_macos_window_size_constraints',
  'require_macos_sandbox_entitlements',
  'avoid_macos_full_disk_access',
  'require_macos_sandbox_exceptions',
  'avoid_macos_hardened_runtime_violations',
  'require_macos_app_transport_security',

  // Professional
  'require_macos_file_access_intent',
  'avoid_macos_deprecated_security_apis',
  'require_macos_hardened_runtime',
  'require_macos_window_restoration',
  'require_macos_entitlements',
  'prefer_macos_keyboard_shortcuts',
  'prefer_macos_menu_bar_integration',
};

/// Rules specific to the Web platform.
const Set<String> webPlatformRules = <String>{
  // Essential
  'avoid_platform_channel_on_web',
  'avoid_web_only_dependencies',
  'require_cors_handling',

  // Recommended
  'avoid_secure_storage_on_web',
  'prefer_deferred_loading_web',
  'avoid_gesture_only_interactions',
  'avoid_hover_only',

  // Professional
  'prefer_url_strategy_for_web',
  'require_web_renderer_awareness',
  'require_focus_indicator',

  // Comprehensive
  'avoid_isar_web_limitations',
};

/// Rules specific to the Windows platform.
const Set<String> windowsPlatformRules = <String>{
  // Recommended
  'avoid_hardcoded_drive_letters',
  'avoid_forward_slash_path_assumption',
  'avoid_case_sensitive_path_comparison',

  // Professional
  'require_windows_single_instance_check',
  'avoid_max_path_risk',
};

/// Rules specific to the Linux platform.
const Set<String> linuxPlatformRules = <String>{
  // Essential
  'avoid_sudo_shell_commands',

  // Recommended
  'avoid_hardcoded_unix_paths',
  'avoid_x11_only_assumptions',

  // Professional
  'prefer_xdg_directory_convention',
  'require_linux_font_fallback',
};

/// Rules shared by Apple platforms (iOS + macOS).
///
/// These appear in both [iosPlatformRules] and [macosPlatformRules] via
/// the [platformRuleSets] map lookup, but are defined here for clarity.
const Set<String> _applePlatformRules = <String>{
  'require_apple_signin_nonce',
  'require_apple_sign_in',
};

/// Rules shared by desktop platforms (macOS, Windows, Linux).
const Set<String> _desktopPlatformRules = <String>{
  'require_menu_bar_for_desktop',
  'require_window_close_confirmation',
  'require_window_size_constraints',
  'prefer_native_file_dialogs',
  'avoid_touch_only_gestures',
  'avoid_gesture_only_interactions',
  'require_focus_indicator',
  'avoid_hover_only',
};

/// All platform sets keyed by platform name.
///
/// Each platform's effective rules include the platform-specific set plus
/// any shared sets (Apple, desktop) that apply.
Map<String, Set<String>> get platformRuleSets => {
  'ios': iosPlatformRules.union(_applePlatformRules),
  'android': androidPlatformRules,
  'macos': macosPlatformRules
      .union(_applePlatformRules)
      .union(_desktopPlatformRules),
  'web': webPlatformRules,
  'windows': windowsPlatformRules.union(_desktopPlatformRules),
  'linux': linuxPlatformRules.union(_desktopPlatformRules),
};

/// All supported platform names.
const List<String> allPlatforms = <String>[
  'ios',
  'android',
  'macos',
  'web',
  'windows',
  'linux',
];

/// Default platform settings.
///
/// Only iOS and Android are enabled by default since most Flutter projects
/// target mobile. Users can enable additional platforms in
/// `analysis_options_custom.yaml`.
const Map<String, bool> defaultPlatforms = <String, bool>{
  'ios': true,
  'android': true,
  'macos': false,
  'web': false,
  'windows': false,
  'linux': false,
};

/// Returns the set of rules that should be disabled based on
/// disabled platforms.
///
/// A rule is disabled if ALL platforms it belongs to are disabled.
/// If a rule appears in multiple platform sets (e.g., Apple Sign In
/// is in both iOS and macOS), it stays enabled as long as at least
/// one of its platforms is enabled.
///
/// Rules not in any platform set are never affected.
Set<String> getRulesDisabledByPlatforms(Map<String, bool> platforms) {
  final disabledPlatforms = platforms.entries
      .where((e) => !e.value)
      .map((e) => e.key)
      .toSet();

  if (disabledPlatforms.isEmpty) return const <String>{};

  final enabledPlatforms = platforms.entries
      .where((e) => e.value)
      .map((e) => e.key)
      .toSet();

  final Set<String> rulesToDisable = <String>{};
  final sets = platformRuleSets;

  for (final platform in disabledPlatforms) {
    final rules = sets[platform] ?? const <String>{};
    for (final rule in rules) {
      // Check if this rule is still relevant via another enabled platform
      bool stillRelevant = false;
      for (final enabledPlatform in enabledPlatforms) {
        if (sets[enabledPlatform]?.contains(rule) ?? false) {
          stillRelevant = true;
          break;
        }
      }
      if (!stillRelevant) {
        rulesToDisable.add(rule);
      }
    }
  }

  return rulesToDisable;
}

// =========================================================================
// PACKAGE/TECHNOLOGY RULE SETS
// =========================================================================
// Rules specific to each third-party package or technology.
// Orthogonal to both tiers and platforms.
//
// A rule can appear in multiple package sets (e.g., a Provider rule about
// Equatable also appears in the Equatable set). A rule is disabled only
// when ALL its packages are disabled.
//
// Generic cross-cutting rules (require_mounted_check, etc.) are NOT in
// any package set -- they remain always-on regardless of package config.
// =========================================================================

// ---------------------------------------------------------------------------
// State Management
// ---------------------------------------------------------------------------

/// Rules specific to the Bloc/Cubit state management package.
const Set<String> blocPackageRules = <String>{
  'avoid_bloc_event_in_constructor',
  'require_bloc_close',
  'require_immutable_bloc_state',
  'require_bloc_observer',
  'avoid_bloc_event_mutation',
  'avoid_bloc_listen_in_build',
  'require_initial_state',
  'require_error_state',
  'avoid_bloc_in_bloc',
  'prefer_sealed_events',
  'require_bloc_transformer',
  'prefer_multi_bloc_provider',
  'avoid_duplicate_bloc_event_handlers',
  'prefer_immutable_bloc_events',
  'prefer_immutable_bloc_state',
  'prefer_sealed_bloc_events',
  'prefer_sealed_bloc_state',
  'prefer_bloc_event_suffix',
  'prefer_bloc_state_suffix',
  'avoid_yield_in_on_event',
  'emit_new_bloc_state_instances',
  'avoid_bloc_public_fields',
  'avoid_bloc_public_methods',
  'require_bloc_selector',
  'avoid_bloc_emit_after_close',
  'avoid_bloc_state_mutation',
  'require_bloc_initial_state',
  'require_bloc_loading_state',
  'require_bloc_error_state',
  'avoid_bloc_context_dependency',
  'require_bloc_consumer_when_both',
  'avoid_bloc_business_logic_in_ui',
  'require_bloc_event_sealed',
  'require_bloc_repository_abstraction',
  'prefer_bloc_transform',
  'avoid_passing_bloc_to_bloc',
  'avoid_passing_build_context_to_blocs',
  'avoid_returning_value_from_cubit_methods',
  'require_bloc_repository_injection',
  'prefer_bloc_hydration',
  'avoid_large_bloc',
  'avoid_overengineered_bloc_states',
  'prefer_cubit_for_simple',
  'prefer_cubit_for_simple_state',
  'prefer_bloc_listener_for_side_effects',
  'prefer_copy_with_for_state',
  'avoid_instantiating_in_bloc_value_provider',
  'avoid_existing_instances_in_bloc_provider',
  'prefer_correct_bloc_provider',
  'require_update_should_notify',
};

/// Rules specific to the Provider state management package.
const Set<String> providerPackageRules = <String>{
  'require_notify_listeners',
  'require_update_should_notify',
  'avoid_provider_of_in_build',
  'avoid_provider_recreate',
  'require_provider_scope',
  'avoid_provider_in_widget',
  'prefer_family_for_params',
  'avoid_change_notifier_in_widget',
  'require_provider_dispose',
  'avoid_circular_provider_deps',
  'require_error_handling_in_async',
  'prefer_notifier_over_state',
  'require_multi_provider',
  'avoid_nested_providers',
  'avoid_instantiating_in_value_provider',
  'dispose_provider_instances',
  'dispose_provided_instances',
  'prefer_immutable_selector_value',
  'prefer_provider_extensions',
  'prefer_nullable_provider_types',
  'prefer_consumer_over_provider_of',
  'avoid_listen_in_async',
  'prefer_context_selector',
  'require_provider_generic_type',
  'require_equatable_props_override',
  'avoid_static_state',
  'avoid_provider_in_init_state',
  'prefer_context_read_in_callbacks',
  'prefer_proxy_provider',
  'require_update_callback',
  'prefer_selector_over_consumer',
  'avoid_provider_value_rebuild',
  'prefer_change_notifier_proxy',
  'prefer_selector_widget',
  'prefer_change_notifier_proxy_provider',
  'prefer_multi_provider',
  'avoid_instantiating_in_bloc_value_provider',
  'avoid_existing_instances_in_bloc_provider',
  'prefer_correct_bloc_provider',
};

/// Rules specific to the Riverpod state management package.
const Set<String> riverpodPackageRules = <String>{
  // From riverpod_rules.dart
  'avoid_ref_read_inside_build',
  'avoid_ref_watch_outside_build',
  'avoid_ref_inside_state_dispose',
  'use_ref_read_synchronously',
  'use_ref_and_state_synchronously',
  'avoid_assigning_notifiers',
  'avoid_notifier_constructors',
  'prefer_immutable_provider_arguments',
  'avoid_unnecessary_consumer_widgets',
  'avoid_nullable_async_value_pattern',
  'require_riverpod_error_handling',
  'avoid_riverpod_state_mutation',
  'prefer_riverpod_select',
  'require_flutter_riverpod_package',
  'prefer_riverpod_auto_dispose',
  'prefer_riverpod_family_for_params',
  // From state_management_rules.dart
  'avoid_watch_in_callbacks',
  'avoid_global_riverpod_providers',
  'prefer_consumer_widget',
  'require_auto_dispose',
  'avoid_ref_in_build_body',
  'avoid_ref_in_dispose',
  'prefer_select_for_partial',
  'prefer_ref_watch_over_read',
  'require_riverpod_lint',
  'require_flutter_riverpod_not_riverpod',
  'avoid_riverpod_navigation',
  'avoid_riverpod_for_network_only',
  'avoid_riverpod_notifier_in_build',
  'require_riverpod_async_value_guard',
  'require_async_value_order',
};

/// Rules specific to the GetX state management package.
const Set<String> getxPackageRules = <String>{
  // From getx_rules.dart
  'require_getx_worker_dispose',
  'require_getx_permanent_cleanup',
  'avoid_getx_context_outside_widget',
  'avoid_getx_global_navigation',
  'require_getx_binding_routes',
  'avoid_getx_dialog_snackbar_in_controller',
  'require_getx_lazy_put',
  // From state_management_rules.dart
  'avoid_get_find_in_build',
  'require_getx_controller_dispose',
  'avoid_obs_outside_controller',
  'proper_getx_super_calls',
  'always_remove_getx_listener',
  'avoid_getx_rx_inside_build',
  'avoid_mutable_rx_variables',
  'dispose_getx_fields',
  'prefer_getx_builder',
  'require_getx_binding',
  'avoid_getx_global_state',
  'avoid_getx_static_context',
  'avoid_tight_coupling_with_getx',
  'avoid_getx_rx_nested_obs',
};

/// Rules specific to the flutter_hooks package.
const Set<String> flutterHooksPackageRules = <String>{
  'avoid_hooks_outside_build',
  'avoid_conditional_hooks',
  'avoid_unnecessary_hook_widgets',
};

// ---------------------------------------------------------------------------
// Data & Code Generation
// ---------------------------------------------------------------------------

/// Rules specific to the Equatable package.
const Set<String> equatablePackageRules = <String>{
  'require_extend_equatable',
  'list_all_equatable_fields',
  'prefer_equatable_mixin',
  'prefer_equatable_stringify',
  'prefer_immutable_annotation',
  'prefer_record_over_equatable',
  'avoid_mutable_field_in_equatable',
  'require_equatable_copy_with',
  'require_copy_with_null_handling',
  'require_deep_equality_collections',
  'avoid_equatable_datetime',
  'prefer_unmodifiable_collections',
  'require_equatable_props_override',
  'avoid_equatable_nested_equality',
};

/// Rules specific to the Freezed code generation package.
const Set<String> freezedPackageRules = <String>{
  'require_freezed_explicit_json',
  'prefer_freezed_default_values',
  'require_freezed_arrow_syntax',
  'require_freezed_private_constructor',
  'avoid_freezed_json_serializable_conflict',
  'require_freezed_json_converter',
  'require_freezed_lint_package',
  'avoid_freezed_for_logic_classes',
  'prefer_freezed_for_data_classes',
  'avoid_freezed_any_map_issue',
};

// ---------------------------------------------------------------------------
// Storage & Database
// ---------------------------------------------------------------------------

/// Rules shared across database packages (Firebase, Isar, Hive, sqflite).
///
/// These generic database rules are unioned into each database package set
/// via [packageRuleSets], so they are disabled only when ALL database
/// packages are disabled.
const Set<String> _databaseSharedRules = <String>{
  'avoid_database_in_build',
  'require_database_migration',
  'require_database_index',
  'prefer_transaction_for_batch',
  'require_yield_after_db_write',
  'suggest_yield_after_db_read',
  'avoid_return_await_db',
};

/// Rules specific to the Firebase platform.
const Set<String> firebasePackageRules = <String>{
  'require_firebase_init_before_use',
  'incorrect_firebase_event_name',
  'incorrect_firebase_parameter_name',
  'prefer_firestore_batch_write',
  'avoid_firestore_in_widget_build',
  'prefer_firebase_remote_config_defaults',
  'require_fcm_token_refresh_handler',
  'require_background_message_handler',
  'require_crashlytics_user_id',
  'require_firebase_app_check',
  'avoid_storing_user_data_in_auth',
  'prefer_firebase_auth_persistence',
  'require_firebase_error_handling',
  'avoid_firebase_realtime_in_build',
  'require_firestore_index',
  'require_firebase_composite_index',
  'avoid_firestore_unbounded_query',
  'avoid_map_markers_in_build',
  'require_map_idle_callback',
  'prefer_marker_clustering',
  'avoid_firebase_user_data_in_auth',
  'require_firebase_app_check_production',
};

/// Rules specific to the Isar database package.
const Set<String> isarPackageRules = <String>{
  'avoid_isar_enum_field',
  'require_isar_collection_annotation',
  'require_isar_id_field',
  'require_isar_close_on_dispose',
  'prefer_isar_async_writes',
  'avoid_isar_transaction_nesting',
  'prefer_isar_batch_operations',
  'avoid_isar_float_equality_queries',
  'require_isar_inspector_debug_only',
  'avoid_isar_clear_in_production',
  'require_isar_links_load',
  'prefer_isar_query_stream',
  'avoid_isar_web_limitations',
  'prefer_isar_index_for_queries',
  'avoid_isar_embedded_large_objects',
  'prefer_isar_lazy_links',
  'avoid_isar_schema_breaking_changes',
  'require_isar_nullable_field',
  'prefer_isar_composite_index',
  'avoid_isar_string_contains_without_index',
  'avoid_cached_isar_stream',
};

/// Rules specific to the Hive database package.
const Set<String> hivePackageRules = <String>{
  'require_hive_initialization',
  'require_hive_type_adapter',
  'require_hive_box_close',
  'prefer_hive_encryption',
  'require_hive_encryption_key_secure',
  'require_hive_database_close',
  'require_type_adapter_registration',
  'prefer_lazy_box_for_large',
  'require_hive_type_id_management',
  'avoid_hive_field_index_reuse',
  'require_hive_field_default_value',
  'require_hive_adapter_registration_order',
  'require_hive_nested_object_adapter',
  'avoid_hive_box_name_collision',
  'prefer_hive_value_listenable',
  'prefer_hive_lazy_box',
  'avoid_hive_binary_storage',
  'require_hive_migration_strategy',
  'avoid_hive_datetime_local',
  'avoid_hive_type_modification',
  'avoid_hive_large_single_entry',
};

/// Rules specific to the shared_preferences package.
const Set<String> sharedPreferencesPackageRules = <String>{
  'require_shared_prefs_prefix',
  'prefer_shared_prefs_async_api',
  'avoid_shared_prefs_in_isolate',
  'avoid_prefs_for_large_data',
  'prefer_typed_prefs_wrapper',
};

/// Rules specific to the sqflite package.
const Set<String> sqflitePackageRules = <String>{
  'avoid_sqflite_type_mismatch',
  'require_sqflite_migration',
};

/// Rules specific to the Drift database package.
const Set<String> driftPackageRules = <String>{
  'avoid_drift_enum_index_reorder',
  'require_drift_database_close',
  'avoid_drift_update_without_where',
  'require_await_in_drift_transaction',
  'require_drift_foreign_key_pragma',
  'avoid_drift_raw_sql_interpolation',
  'prefer_drift_batch_operations',
  'require_drift_stream_cancel',
  'avoid_drift_database_on_main_isolate',
  'avoid_drift_log_statements_production',
  'avoid_drift_get_single_without_unique',
  'prefer_drift_use_columns_false',
  'avoid_drift_lazy_database',
  'prefer_drift_isolate_sharing',
  'avoid_drift_query_in_migration',
  'require_drift_schema_version_bump',
  'avoid_drift_foreign_key_in_migration',
  'require_drift_reads_from',
  'avoid_drift_unsafe_web_storage',
  'avoid_drift_close_streams_in_tests',
  'avoid_drift_nullable_converter_mismatch',
};

// ---------------------------------------------------------------------------
// Networking
// ---------------------------------------------------------------------------

/// Rules specific to the Dio HTTP client package.
const Set<String> dioPackageRules = <String>{
  'require_cancel_token',
  'require_dio_timeout',
  'require_dio_error_handling',
  'require_dio_interceptor_error_handler',
  'prefer_dio_cancel_token',
  'require_dio_ssl_pinning',
  'avoid_dio_form_data_leak',
  'avoid_dio_debug_print_production',
  'require_dio_singleton',
  'prefer_dio_base_options',
  'avoid_dio_without_base_url',
  'prefer_dio_over_http',
  'require_dio_response_type',
  'require_dio_retry_interceptor',
  'prefer_dio_transformer',
};

/// Rules specific to the GraphQL package.
const Set<String> graphqlPackageRules = <String>{
  'avoid_graphql_string_queries',
};

/// Rules specific to the Supabase package.
const Set<String> supabasePackageRules = <String>{
  'require_supabase_error_handling',
  'avoid_supabase_anon_key_in_code',
  'require_supabase_realtime_unsubscribe',
};

// ---------------------------------------------------------------------------
// DI & Services
// ---------------------------------------------------------------------------

/// Rules specific to the get_it dependency injection package.
const Set<String> getItPackageRules = <String>{
  'avoid_service_locator_in_widgets',
  'avoid_too_many_dependencies',
  'avoid_internal_dependency_creation',
  'prefer_abstract_dependencies',
  'avoid_singleton_for_scoped_dependencies',
  'avoid_circular_di_dependencies',
  'prefer_null_object_pattern',
  'require_typed_di_registration',
  'avoid_functions_in_register_singleton',
  'require_getit_registration_order',
  'require_default_config',
  'prefer_constructor_injection',
  'require_di_scope_awareness',
  'avoid_di_in_widgets',
  'prefer_abstraction_injection',
  'prefer_lazy_singleton_registration',
};

/// Rules specific to the workmanager package.
const Set<String> workmanagerPackageRules = <String>{
  'require_workmanager_constraints',
  'require_workmanager_result_return',
};

// ---------------------------------------------------------------------------
// UI & Device
// ---------------------------------------------------------------------------

/// Rules specific to the url_launcher package.
const Set<String> urlLauncherPackageRules = <String>{
  'require_url_launcher_can_launch_check',
  'avoid_url_launcher_simulator_tests',
  'prefer_url_launcher_fallback',
  'require_url_launcher_mode',
  'require_url_launcher_error_handling',
};

/// Rules specific to the geolocator package.
const Set<String> geolocatorPackageRules = <String>{
  'require_geolocator_battery_awareness',
  'require_geolocator_permission_check',
  'require_geolocator_service_enabled',
  'require_geolocator_stream_cancel',
  'require_geolocator_error_handling',
  'require_geolocator_timeout',
  'prefer_geolocator_distance_filter',
};

/// Rules specific to the QR scanner packages.
const Set<String> qrScannerPackageRules = <String>{
  'require_qr_scan_feedback',
  'avoid_qr_scanner_always_active',
  'require_qr_content_validation',
  'require_qr_permission_check',
};

/// Rules specific to the Flame game engine package.
const Set<String> flamePackageRules = <String>{
  'avoid_creating_vector_in_update',
  'avoid_redundant_async_on_load',
};

// ---------------------------------------------------------------------------
// Package rule sets, constants, and filtering
// ---------------------------------------------------------------------------

/// All package sets keyed by package name.
///
/// Each package's effective rules include the package-specific set plus
/// any shared sets (database) that apply. A rule is disabled only when
/// ALL packages that contain it are disabled.
Map<String, Set<String>> get packageRuleSets => {
  'bloc': blocPackageRules,
  'provider': providerPackageRules,
  'riverpod': riverpodPackageRules,
  'getx': getxPackageRules,
  'flutter_hooks': flutterHooksPackageRules,
  'equatable': equatablePackageRules,
  'freezed': freezedPackageRules,
  'firebase': firebasePackageRules.union(_databaseSharedRules),
  'isar': isarPackageRules.union(_databaseSharedRules),
  'hive': hivePackageRules.union(_databaseSharedRules),
  'shared_preferences': sharedPreferencesPackageRules,
  'sqflite': sqflitePackageRules.union(_databaseSharedRules),
  'drift': driftPackageRules.union(_databaseSharedRules),
  'dio': dioPackageRules,
  'graphql': graphqlPackageRules,
  'supabase': supabasePackageRules,
  'get_it': getItPackageRules,
  'workmanager': workmanagerPackageRules,
  'url_launcher': urlLauncherPackageRules,
  'geolocator': geolocatorPackageRules,
  'qr_scanner': qrScannerPackageRules,
  'flame': flamePackageRules,
};

/// All supported package names.
const List<String> allPackages = <String>[
  'bloc',
  'provider',
  'riverpod',
  'getx',
  'flutter_hooks',
  'equatable',
  'freezed',
  'firebase',
  'isar',
  'hive',
  'shared_preferences',
  'sqflite',
  'drift',
  'dio',
  'graphql',
  'supabase',
  'get_it',
  'workmanager',
  'url_launcher',
  'geolocator',
  'qr_scanner',
  'flame',
];

/// Default package settings.
///
/// All packages are enabled by default for backward compatibility.
/// Users can disable packages they don't use in
/// `analysis_options_custom.yaml`.
const Map<String, bool> defaultPackages = <String, bool>{
  'bloc': true,
  'provider': true,
  'riverpod': true,
  'getx': true,
  'flutter_hooks': true,
  'equatable': true,
  'freezed': true,
  'firebase': true,
  'isar': true,
  'hive': true,
  'shared_preferences': true,
  'sqflite': true,
  'drift': true,
  'dio': true,
  'graphql': true,
  'supabase': true,
  'get_it': true,
  'workmanager': true,
  'url_launcher': true,
  'geolocator': true,
  'qr_scanner': true,
  'flame': true,
};

/// Returns the set of rules that should be disabled based on
/// disabled packages.
///
/// A rule is disabled if ALL packages it belongs to are disabled.
/// If a rule appears in multiple package sets (e.g., a Provider rule
/// about Equatable is in both sets), it stays enabled as long as at
/// least one of its packages is enabled.
///
/// Rules not in any package set are never affected.
Set<String> getRulesDisabledByPackages(Map<String, bool> packages) {
  final disabledPackages = packages.entries
      .where((e) => !e.value)
      .map((e) => e.key)
      .toSet();

  if (disabledPackages.isEmpty) return const <String>{};

  final enabledPackages = packages.entries
      .where((e) => e.value)
      .map((e) => e.key)
      .toSet();

  final Set<String> rulesToDisable = <String>{};
  final sets = packageRuleSets;

  for (final package in disabledPackages) {
    final rules = sets[package] ?? const <String>{};
    for (final rule in rules) {
      // Check if this rule is still relevant via another enabled package
      bool stillRelevant = false;
      for (final enabledPackage in enabledPackages) {
        if (sets[enabledPackage]?.contains(rule) ?? false) {
          stillRelevant = true;
          break;
        }
      }
      if (!stillRelevant) {
        rulesToDisable.add(rule);
      }
    }
  }

  return rulesToDisable;
}
