
/// Tier-based rule configuration for saropa_lints.
///
/// Each tier builds on the previous one:
/// - essential: Critical rules (~45 rules) - prevents crashes, security issues
/// - recommended: Essential + common mistakes (~150 rules) - default for most teams
/// - professional: Recommended + architecture/testing (~350 rules) - enterprise teams
/// - comprehensive: Professional + thorough coverage (~700 rules) - quality obsessed
/// - insanity: Everything (~475+ rules) - greenfield projects
library;

export 'tiers.dart' show getRulesForTier;

// cspell:ignore require_sqflite_whereargs getit futureor shouldrepaint itemextent singlechildscrollview

/// Stylistic tier rules - rules focused on code style, formatting, and opinionated patterns.
const Set<String> stylisticRules = <String>{
  'always_fail_test_case', // test rule
  'enforce_arguments_ordering',
  'avoid_generic_greeting_text',
  'avoid_setstate_in_build',
  'capitalize_comment_start',
  'prefer_arguments_ordering',
  'require_capitalize_comment',
  'prefer_argument_ordering',
  'prefer_catch_over_on',
  'prefer_error_suffix',
  'prefer_exception_suffix',
  'prefer_generic_exception_type',
  'prefer_initializing_formal',
  'prefer_kebab_tag',
  'prefer_on_catch',
  'prefer_rethrow_throw_e',
  'prefer_single_exit',
  'prefer_sorted_member',
  'prefer_sorted_parameter',
  'prefer_specific_exception',
  'prefer_static_method_type',
  'require_comment_capitalization_text',
  'require_custom_firebase',
  'require_purchase_complete',
  'require_purchase_verification',
  'require_save_confirm',
  'saropa_lints',
  'require_tag_name_text',
  'user_clicked_btn',
};

/// Essential tier rules - Critical rules that prevent crashes, data loss, and security holes.
const Set<String> essentialRules = <String>{
  // Memory Leaks - Controllers (dispose)
  'require_dispose_method',
  'require_field_dispose',
  'require_animation_disposal',
  'avoid_undisposed_instances',
  'require_value_notifier_dispose',
  'require_focus_node_dispose',
  'require_page_controller_dispose',
  'prefer_list_first',
  'require_media_player_dispose',
  'avoid_dynamic_type',
  // Memory Leaks - Timers & Subscriptions (cancel)
  'avoid_variable_shadowing',
  'avoid_unassigned_stream_subscriptions',
  'prefer_list_last',
  'require_stream_controller_dispose',
  'enforce_member_ordering',
  'always_remove_listener',
  'avoid_string_substring',
  // Flutter Lifecycle
  'prefer_single_container',
  'avoid_inherited_widget_in_initstate',
  'require_comment_formatting',
  'avoid_unsafe_setstate',
  'prefer_api_pagination', // INFO - memory efficiency
  'avoid_recursive_widget_calls',
  'avoid_continue_statement',
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
  'require_provider_dispose', // Resource cleanup
  'proper_getx_super_calls', // Broken lifecycle
  'always_remove_getx_listener', // Memory leak
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
  'require_database_close',
  'require_websocket_close',

  // Error Handling
  'avoid_swallowing_exceptions',
  'avoid_losing_stack_trace',

  'avoid_print_error', // Print for error logging loses errors in production

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
  'avoid_test_sleep', // WARNING - blocks test runner, use pump() instead

  // JSON Serialization (Essential - runtime crashes)
  'avoid_not_encodable_in_to_json', // WARNING - non-JSON types cause runtime errors

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

  // =========================================================================
  // ROADMAP_NEXT Parts 1-7 Rules
  // =========================================================================

  // Part 1 - Isar Database Rules (Essential - prevent data corruption)
  'require_isar_collection_annotation', // ERROR - missing annotation
  'require_isar_id_field', // ERROR - missing ID field
  'require_isar_close_on_dispose', // WARNING - resource leak
  'avoid_isar_schema_breaking_changes', // ERROR - data corruption
  'require_isar_links_load', // ERROR - accessing unloaded links
  'avoid_isar_transaction_nesting', // ERROR - deadlocks
  'require_isar_non_nullable_migration', // ERROR - data corruption
  'require_isar_inspector_debug_only', // WARNING - production exposure
  'avoid_isar_clear_in_production', // ERROR - data loss

  // Part 2 - Dispose Pattern Rules (Essential - memory leaks)
  'require_change_notifier_dispose', // ERROR - memory leak
  'require_receive_port_close', // ERROR - resource leak
  'require_socket_close', // ERROR - resource leak
  'require_debouncer_cancel', // ERROR - timer leak
  'require_interval_timer_cancel', // ERROR - timer leak
  'require_file_handle_close', // WARNING - file handle leak

  // Part 3 - Widget Lifecycle Rules (Essential - crashes)
  'require_super_dispose_call', // ERROR - broken lifecycle
  'require_super_init_state_call', // ERROR - broken lifecycle
  'avoid_set_state_in_dispose', // ERROR - disposed widget
  'avoid_navigation_in_build', // ERROR - navigation chaos

  // Part 4 - Missing Parameter Rules (Essential)
  'require_provider_generic_type', // ERROR - wrong type inference
  'require_text_form_field_in_form', // WARNING - broken validation

  // Part 5 - Exact API Pattern Rules (Essential)
  'require_flutter_riverpod_package', // ERROR - import error
  'avoid_bloc_emit_after_close', // ERROR - emit on closed bloc
  'avoid_bloc_state_mutation', // ERROR - equality bugs
  'require_bloc_initial_state', // ERROR - null state
  'require_physics_for_nested_scroll', // WARNING - scroll conflict
  'require_animated_builder_child', // WARNING - performance
  'require_rethrow_preserve_stack', // WARNING - lost stack trace
  'require_https_over_http', // ERROR - security
  'require_wss_over_ws', // ERROR - security
  'avoid_late_without_guarantee', // WARNING - LateInitializationError

  // Part 6 - Additional Easy Rules (Essential)
  'require_secure_storage_auth_data', // ERROR - security
  'avoid_freezed_json_serializable_conflict', // ERROR - build failure
  'require_freezed_arrow_syntax', // ERROR - wrong fromJson
  'require_freezed_private_constructor', // ERROR - build failure
  'require_equatable_immutable', // ERROR - equality bugs
  'require_equatable_props_override', // ERROR - equality bugs
  'avoid_equatable_mutable_collections', // WARNING - equality bugs
  'avoid_static_state', // WARNING - state leaks between tests

  // Part 7 - Package-Specific Rules (Essential)
  'avoid_dio_debug_print_production', // WARNING - security
  'require_url_launcher_error_handling', // WARNING - crash
  'require_image_picker_error_handling', // WARNING - crash
  'require_geolocator_timeout', // WARNING - hang
  'require_connectivity_subscription_cancel', // ERROR - leak
  'require_notification_handler_top_level', // ERROR - crash
  'require_permission_denied_handling', // WARNING - crash

  // Image Picker Rules (Essential - OOM prevention)
  'prefer_image_picker_max_dimensions', // WARNING - OOM on high-res cameras

  // Notification Rules (Essential - silent failure prevention)
  'require_notification_initialize_per_platform', // WARNING - missing platform settings

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

  'require_method_channel_error_handling', // WARNING - crash prevention
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
  'avoid_webview_insecure_content', // ERROR - mixed content security
  'require_data_encryption', // ERROR - sensitive data must be encrypted
  'require_secure_password_field', // ERROR - password field security

  // JSON/Type Safety (Critical)
  'avoid_dynamic_json_access', // ERROR - unsafe dynamic access
  'avoid_dynamic_json_chains', // ERROR - chained dynamic access crashes
  'avoid_unrelated_type_casts', // ERROR - invalid cast crash
  'require_null_safe_json_access', // ERROR - null safety in JSON

  // Platform/Permissions (Critical)
  'avoid_platform_channel_on_web', // ERROR - crashes on web
  'require_image_picker_permission_android', // ERROR - permission required
  'require_image_picker_permission_ios', // ERROR - permission required
  'require_permission_manifest_android', // ERROR - manifest entry required
  'require_permission_plist_ios', // ERROR - plist entry required
  'require_url_launcher_queries_android', // ERROR - queries element required
  'require_url_launcher_schemes_ios', // ERROR - LSApplicationQueriesSchemes

  // Memory/Resource Leaks (Critical/High)
  'avoid_stream_subscription_in_field', // ERROR - subscription leak
  'avoid_websocket_memory_leak', // ERROR - WebSocket leak
  'prefer_dispose_before_new_instance', // ERROR - dispose before reassign
  'require_dispose_implementation', // ERROR - disposable must implement dispose
  'require_video_player_controller_dispose', // ERROR - video controller leak

  // Widget Lifecycle (Critical/High)
  'check_mounted_after_async', // ERROR - setState after dispose
  'avoid_ref_in_build_body', // ERROR - ref.watch in wrong place
  'avoid_flashing_content', // ERROR - accessibility seizure risk

  // Animation (High)
  'avoid_animation_rebuild_waste', // WARNING - animation performance
  'avoid_overlapping_animations', // WARNING - animation conflicts

  // Navigation (High)
  'prefer_maybe_pop', // WARNING - safe navigation
  'require_deep_link_fallback', // WARNING - deep link error handling
  'require_stepper_validation', // WARNING - stepper form validation

  // Firebase/Backend (High)
  'prefer_firebase_remote_config_defaults', // WARNING - config defaults
  'require_background_message_handler', // WARNING - FCM background
  'require_fcm_token_refresh_handler', // WARNING - token refresh

  // Forms/Input (High)
  'require_validator_return_null', // WARNING - validator pattern
  'avoid_image_picker_large_files', // WARNING - OOM prevention

  // WebView (High)
  'prefer_webview_javascript_disabled', // WARNING - security default
  'require_webview_error_handling', // WARNING - error handling
  'require_webview_navigation_delegate', // WARNING - navigation control
  'require_websocket_message_validation', // WARNING - message validation

  // Data/Storage (High)
  'prefer_utc_for_storage', // WARNING - timezone consistency
  'require_database_migration', // WARNING - migration safety
  'require_enum_unknown_value', // WARNING - future-proof enums

  // UI/UX (High)
  'prefer_html_escape', // WARNING - XSS prevention
  'require_error_widget', // WARNING - error boundary
  'require_feature_flag_default', // WARNING - feature flag safety
  'require_immutable_bloc_state', // WARNING - state immutability
  'require_map_idle_callback', // WARNING - map performance
  'require_media_loading_state', // WARNING - loading indicators

  // State Management (High)
  'prefer_bloc_listener_for_side_effects', // WARNING - side effect pattern

  // Network (High)
  'require_cors_handling', // WARNING - CORS on web
};

/// Recommended tier rules - Essential + common mistakes, performance basics.
const Set<String> recommendedOnlyRules = <String>{
  'prefer_single_exit_point',
  // BuildContext Safety (Recommended)
  'prefer_kebab_tag_name',
  'prefer_rethrow_over_throw_e',
  'prefer_sorted_members',
  'prefer_sorted_parameters',
  'avoid_context_in_async_static', // WARNING - async static with context

  // Memory Management Best Practices
  'nullify_after_dispose',
  'require_auto_dispose',

  // Performance
  'avoid_expensive_build',
  'prefer_const_child_widgets',
  'avoid_listview_without_item_extent',
  'avoid_shrink_wrap_in_lists',
  'avoid_mediaquery_in_build',
  'prefer_static_method',
  'require_comment_capitalization',
  'require_custom_firebase_usage',
  'require_purchase_verification',
  'require_save_confirmation',
  'require_tag_name_text',
  'user_clicked_button',
  'prefer_const_widgets_in_lists',
  'prefer_value_listenable_builder',

  // Build Method Anti-patterns (Performance/UX)
  'avoid_gradient_in_build',
  'avoid_snackbar_in_build',
  'avoid_analytics_in_build',
  'avoid_json_encode_in_build',
  'avoid_canvas_operations_in_build',
  'prefer_expanded_at_call_site', // WARNING - Expanded in build() couples to Flex parent

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
  'prefer_change_notifier_proxy', // INFO - use context.read() in callbacks
  'require_bloc_event_sealed', // INFO - sealed classes for exhaustive matching
  'avoid_getx_global_state', // INFO - avoid Get.put/Get.find for global state

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
  'prefer_future_wait', // INFO - parallel independent awaits

  // Code Quality
  'avoid_very_long_files', // 1000 lines - code smell
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
  'no_boolean_literal_compare', // INFO - use boolean expression directly

  // Collections
  'avoid_map_keys_contains',
  'avoid_collection_equality_checks',
  'avoid_missing_enum_constant_in_map',
  'avoid_enum_values_by_index',
  'prefer_contains_method_usage',
  'prefer_first_method_usage',
  'prefer_last_method_usage',
  'prefer_where_or_null', // Prefer whereOrNull for idiomatic Dart

  'require_test_assertions',

  'avoid_hardcoded_test_delays',

  'avoid_test_coupling',

  'avoid_real_dependencies_in_tests',

  'prefer_test_wrapper',

  // State Management (Batch 10)

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
  'require_form_auto_validate_mode',
  'require_autofill_hints',
  'prefer_on_field_submitted',

  // Duration & DateTime (Plan Group F)
  'prefer_duration_constants',

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
  'prefer_getx_builder',
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
  'require_bloc_loading_state', // INFO - UX
  'require_bloc_error_state', // INFO - UX

  // Part 7 - Dio Rules (Recommended - maintainability)
  'avoid_dio_without_base_url', // INFO - consistency

  // Part 7 - Image Picker Rules (Recommended - UX)
  'require_image_picker_source_choice', // INFO - flexibility

  // Cached Image Rules (Recommended - UX)
  'prefer_cached_image_fade_animation', // INFO - smooth image loading

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
  'avoid_duplicate_test_assertions', // Prevents redundant assertions in tests
  'avoid_real_network_calls_in_tests', // Ensures tests do not hit real network
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
  'require_getit_registration_order', // WARNING - startup crash
  'require_default_config', // WARNING - startup crash
  'avoid_builder_index_out_of_bounds', // WARNING - runtime crash

  'prefer_ios_safe_area', // INFO - iOS notch/Dynamic Island handling
  'avoid_ios_hardcoded_status_bar', // WARNING - device-specific issues
  'require_ios_platform_check', // WARNING - platform-specific crashes
  'avoid_ios_background_fetch_abuse', // WARNING - iOS background limits
  'require_universal_link_validation', // INFO - deep link testing
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
  'require_ios_lifecycle_handling', // INFO - proper app lifecycle
  'require_ios_nfc_capability_check', // WARNING - device compatibility
  'require_ios_callkit_integration', // WARNING - VoIP requirement
  'require_ios_photo_library_limited_access', // INFO - iOS 14+ handling

  'require_ios_method_channel_cleanup', // WARNING - memory leak prevention
  'avoid_ios_force_unwrap_in_callbacks', // WARNING - crash prevention
  'require_ios_deployment_target_consistency', // WARNING - API compatibility
  'require_ios_dynamic_island_safe_zones', // WARNING - device layout
  'require_ios_keychain_for_credentials', // ERROR - security critical
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
  'prefer_returning_conditional_expressions', // INFO - cleaner code
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
  'avoid_shrink_wrap_in_scroll', // INFO - shrinkWrap performance
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
  'avoid_stack_overflow', // INFO - recursion depth
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
  'prefer_cubit_for_simple_state', // INFO - Cubit vs Bloc choice
  'prefer_selector_over_consumer', // INFO - targeted rebuilds
  'require_bloc_consumer_when_both', // INFO - BlocConsumer pattern

  // Accessibility (Medium)
  'avoid_screenshot_sensitive', // INFO - screenshot protection
  'avoid_semantics_exclusion', // INFO - semantics exclusion
  'prefer_merge_semantics', // INFO - merge semantics
  'avoid_small_text', // INFO - minimum text size

  // Data/Collections (Medium)
  'avoid_misused_set_literals', // INFO - set literal usage
  'avoid_non_null_assertion', // INFO - null assertion warning
  'move_variable_closer_to_its_usage', // INFO - variable scope

  // Images/Media (Medium)
  'prefer_asset_image_for_local', // INFO - local image loading
  'prefer_image_picker_request_full_metadata', // INFO - EXIF metadata
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
  'require_intl_locale_initialization', // INFO - intl locale init
  'require_notification_timezone_awareness', // INFO - timezone handling

  // Misc (Medium)
  'prefer_adequate_spacing', // INFO - spacing consistency
  'prefer_safe_area_aware', // INFO - safe area handling
  'prefer_wrap_over_overflow', // INFO - overflow handling
  'require_default_text_style', // INFO - text style defaults
  'require_freezed_explicit_json', // INFO - Freezed JSON
  'require_webview_progress_indicator', // INFO - WebView progress
  'prefer_sorted_pattern_fields', // INFO - pattern field ordering
  'prefer_sorted_record_fields', // INFO - record field ordering

  // Additional orphans (missed in initial pass)
  'require_image_error_fallback', // INFO - image error handling
  'prefer_ignore_pointer', // INFO - IgnorePointer for non-interactive
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

  // Scroll/List Performance (Professional - optimization hints)
  'prefer_item_extent', // INFO - better scroll performance
  'prefer_prototype_item', // INFO - consistent sizing optimization
  'require_add_automatic_keep_alives_off', // INFO - memory efficiency

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
  'require_bloc_repository_abstraction', // INFO - abstract deps for testability
  'prefer_bloc_transform', // INFO - debounce/throttle for search events
  'prefer_selector_widget', // INFO - targeted rebuilds vs full Consumer

  // State Management (Batch 10)
  'require_update_should_notify_context',
  'prefer_consumer_widget_pattern',
  'avoid_provider_of_in_build_method',
  'avoid_get_find_in_build_method',
  'prefer_cubit_for_simple_state',
  'require_bloc_observer_instance',
  'prefer_select_for_partial_state',
  'prefer_family_for_params_pattern',
  'avoid_expensive_computation_in_build',
  'require_equatable_extension',
  'prefer_equatable_mixin_pattern',
  'require_image_cache_management',
  'prefer_void_callback_type',

  'prefer_symbol_over_key_pattern',
  'require_submit_button_state',
  'avoid_notifier_constructors_usage',
  'prefer_immutable_provider_arguments_type',
  'require_form_field_controller',
  'prefer_nullable_provider_types_pattern',

  'prefer_immutable_bloc_events_pattern',
  'prefer_immutable_bloc_state_pattern',
  'prefer_sealed_bloc_events_pattern',
  'prefer_sealed_bloc_state_pattern',
  'require_bloc_repository_abstraction_layer', // INFO - abstract deps for testability
  'prefer_bloc_transform_pattern', // INFO - debounce/throttle for search events
  'prefer_selector_widget_pattern', // INFO - targeted rebuilds vs full Consumer
  'avoid_production_config_in_tests',
  'require_error_state_context',
  'avoid_bloc_in_bloc_pattern',
  'prefer_sealed_events_pattern',
  'require_test_setup_teardown',
  'prefer_copy_with_for_state_class', // Ensures state classes have copyWith for immutability
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
  'prefer_constructor_injection', // INFO - constructor DI over setter injection

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
  'avoid_medium_files', // 300 lines - starting to get complex
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
  'prefer_http_connection_reuse', // INFO - performance
  'avoid_redundant_requests', // INFO - resource efficiency
  'prefer_pagination', // INFO - memory efficiency
  'require_cancel_token', // WARNING - cancel requests on dispose

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
  'prefer_ble_mtu_negotiation', // Performance - BLE data transfer efficiency

  // QR Scanner (Plan Group I)
  'avoid_qr_scanner_always_active',

  // GraphQL (Plan Group K)
  'avoid_graphql_string_queries', // Type safety - use codegen

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
  'avoid_circular_imports',

  // Test rules (roadmap_up_next)
  'require_test_cleanup',
  'require_accessibility_tests',
  'prefer_test_data_builder',
  'prefer_test_variant',
  'require_animation_tests',

  // Part 5 - Database Rules (Professional)
  'require_sqflite_transaction',
  'prefer_sqflite_batch',
  'require_sqflite_error_handling',
  'require_sqflite_close',
  'avoid_sqflite_reserved_words', // SQLite reserved words cause syntax errors
  'require_hive_box_close',
  'prefer_hive_encryption',
  'require_hive_database_close', // WARNING - database opened without close method
  'prefer_lazy_box_for_large', // INFO - large collections should use openLazyBox

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
  'prefer_geolocator_distance_filter', // INFO - battery optimization

  // Part 6 - State Management Rules (Professional)
  'avoid_bloc_public_methods',
  'require_bloc_selector',
  'prefer_selector',
  'require_getx_binding',

  // Part 6 - Firebase Rules (Professional)
  'require_crashlytics_user_id',
  'require_firebase_app_check',

  // Part 6 - Theming Rules (Professional)
  'avoid_elevation_opacity_in_dark',
  'prefer_theme_extensions',

  // Part 6 - Security Rules (Professional)
  'prefer_local_auth',

  // Part 6 - Performance Rules (Professional)
  'prefer_inherited_widget_cache',
  'prefer_layout_builder_over_media_query',

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
  'prefer_dot_shorthand',
  'require_future_wait_error_handling',
  'require_stream_on_done',
  'require_completer_error_handling',

  // =========================================================================
  // ROADMAP_NEXT Parts 1-7 Rules (Professional)
  // =========================================================================

  // Part 1 - Isar Database Rules (Professional - optimization)
  'prefer_isar_index_for_queries', // INFO - query performance
  'avoid_isar_embedded_large_objects', // WARNING - memory
  'prefer_isar_async_writes', // INFO - UI responsiveness
  'prefer_isar_lazy_links', // INFO - large collections
  'avoid_isar_web_limitations', // WARNING - platform compat
  'prefer_isar_batch_operations', // INFO - performance
  'avoid_isar_string_contains_without_index', // WARNING - performance
  'prefer_isar_composite_index', // INFO - query performance
  'prefer_isar_query_stream', // INFO - reactivity
  'avoid_isar_float_equality_queries', // WARNING - precision
  'avoid_cached_isar_stream', // ERROR - Isar streams must not be cached

  // Part 7 - Dio Rules (Professional - architecture)
  'require_dio_singleton', // INFO - consistency
  'prefer_dio_base_options', // INFO - maintainability

  // Part 7 - GoRouter Rules (Professional - best practice)
  'prefer_go_router_redirect_auth', // INFO - separation of concerns
  'require_go_router_typed_params', // INFO - type safety

  // Part 7 - Provider Rules (Professional - best practice)
  'avoid_provider_in_init_state', // WARNING - initState timing issue
  'prefer_context_read_in_callbacks', // WARNING - unnecessary rebuilds

  // Part 7 - Hive Rules (Professional - data integrity)
  'require_hive_type_id_management', // INFO - typeId documentation advisory

  // Part 7 - Image Picker Rules (Professional - error handling)
  'require_image_picker_result_handling', // WARNING - null result crash

  // Part 7 - Cached Image Rules (Professional - performance)
  'avoid_cached_image_in_build', // WARNING - cache key instability

  // Part 7 - SQLite Rules (Professional - migration safety)
  'require_sqflite_migration', // WARNING - migration version check

  // Part 7 - Permission Rules (Professional - UX/compliance)
  'require_permission_rationale', // INFO - Android best practice
  'require_permission_status_check', // WARNING - crash prevention
  'require_notification_permission_android13', // WARNING - Android 13+

  // URL Launcher Rules (Professional - consistency)
  'require_url_launcher_mode', // INFO - cross-platform consistency

  // SQLite Rules (Professional - performance)
  'avoid_sqflite_read_all_columns', // INFO - memory/bandwidth efficiency

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
};

/// Rules that are only included in the comprehensive tier (not in professional).
const Set<String> comprehensiveOnlyRules = <String>{
  // Add rules here that are not in essential, recommended, or professional, but are in comprehensive.
  // If you add a new set for comprehensive, list them here.
};

/// Rules that are only included in the insanity tier (not in comprehensive).
const Set<String> insanityOnlyRules = <String>{
  // Add rules here that are not in essential, recommended, professional, or comprehensive, but are in insanity.
  // If you add a new set for insanity, list them here.
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
      return essentialRules.union(recommendedOnlyRules).union(professionalOnlyRules);
    case 'comprehensive':
      // comprehensive = professional + comprehensiveOnly
      return essentialRules.union(recommendedOnlyRules).union(professionalOnlyRules).union(comprehensiveOnlyRules);
    case 'insanity':
      // insanity = all rules
      return essentialRules.union(recommendedOnlyRules).union(professionalOnlyRules).union(comprehensiveOnlyRules).union(insanityOnlyRules);
    default:
      // fallback to essential
      return essentialRules;
  }
}