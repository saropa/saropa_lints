# Quick Fix Plan: Analysis + Checklist

**Goal:** Increase quick fix coverage by implementing fixes in priority order, with fixtures + tests, and validating via the audit script.

**Current state:** Run `python scripts/list_rules_without_fixes.py` for an up-to-date list. Batches 12+ (conversation batches 4–8) added 28+ quick fixes; 50+ rules now have at least one fix from this effort.

---

## What’s left to do

### Broad summary

- **Batches 1–11 are done.** Those batches added many quick fixes (structure, bloc, performance, naming, type, code_quality, unnecessary_code, control flow, return, error handling, async, equality, collection, formatting, complexity). The plan no longer lists the individual completed items; only the batch headers and exit criteria remain.
- **What’s actually left:** (1) one-time pre-flight and post-batch audits if you haven’t run them, (2) one optional fix in the “Batch 6” area, (3) re-run the full audit and record numbers, (4) **future batches (Batch 12+)** — add more quick fixes by choosing rules from Part 1 and following the batch workflow.

So: **no remaining work inside Batches 1–11.** Remaining work is housekeeping (audits), the optional Batch 6 fix, and planning/doing **Batch 12+** using Part 1.

### Detail: actionable items

| Priority | What | Where in doc |
|--------|------|----------------|
| **One-time** | Run `python scripts/publish.py` (audit-only); record fix count and “files needing quick fixes”. Confirm `dart analyze --fatal-infos` and `dart test` pass. Optionally create a branch for quick-fix work. | **A. Pre-flight** |
| **Optional** | Add a second fix for `avoid_synchronous_file_io`: when the call is inside an async function, also insert `await` at the call site (multi-edit). | **H. Batch 6** |
| **Ongoing** | Run full audit again; record new fix count and worst-offending files. | **I. After Batch 6** |
| **Next batches** | Add **Batch 12+** by picking more rules from **Part 1** (e.g. structure_rules, bloc_rules, performance_rules, naming_style, type_rules “EASY” candidates, or “Additional EASY buckets” like firebase_rules, drift_rules, widget_patterns_require_rules, iOS). For each new fix: follow **B. Batch workflow** (add fix producer → wire to rule → fixture → test → format/analyze/test → re-run audit). | **Part 1** + **B** + **I** |

---

## Part 1 — Analysis

*Generated from codebase scan + spot-reading rule sources.*

### 1. Rules missing quick fixes (full checklist)

Every rule below has no quick fix. For each: add a fix producer under `lib/src/fixes/**`, wire it on the rule with `fixGenerators`, add a fixture and test. See **B. Batch workflow** and **2. How quick fixes work** below. Regenerate this list with: `python scripts/list_rules_without_fixes.py`.

#### architecture_rules.dart
  - [ ] avoid_business_logic_in_ui
  - [ ] avoid_circular_dependencies
  - [ ] avoid_circular_imports
  - [ ] avoid_cross_feature_dependencies
  - [ ] avoid_direct_data_access_in_ui
  - [ ] avoid_god_class
  - [ ] avoid_singleton_pattern
  - [ ] avoid_touch_only_gestures
  - [ ] avoid_ui_in_domain_layer
  - [ ] prefer_builder_pattern

#### dependency_injection_rules.dart
  - [ ] avoid_circular_di_dependencies
  - [ ] avoid_di_in_widgets
  - [ ] avoid_internal_dependency_creation
  - [ ] avoid_service_locator_in_widgets
  - [ ] avoid_too_many_dependencies
  - [ ] prefer_abstract_dependencies
  - [ ] prefer_abstraction_injection
  - [ ] prefer_constructor_injection
  - [ ] prefer_null_object_pattern
  - [ ] require_default_config
  - [ ] require_di_scope_awareness
  - [ ] require_interface_for_dependency
  - [ ] require_typed_di_registration

#### disposal_rules.dart
  - [ ] avoid_websocket_memory_leak
  - [ ] dispose_class_fields
  - [ ] prefer_deactivate_for_cleanup
  - [ ] prefer_dispose_before_new_instance
  - [ ] require_change_notifier_dispose
  - [ ] require_debouncer_cancel
  - [ ] require_dispose_implementation
  - [ ] require_file_handle_close
  - [ ] require_interval_timer_cancel
  - [ ] require_lifecycle_observer
  - [ ] require_media_player_dispose
  - [ ] require_page_controller_dispose
  - [ ] require_receive_port_close
  - [ ] require_socket_close
  - [ ] require_stream_subscription_cancel
  - [ ] require_tab_controller_dispose
  - [ ] require_text_editing_controller_dispose
  - [ ] require_video_player_controller_dispose

#### lifecycle_rules.dart
  - [ ] avoid_work_in_paused_state
  - [ ] require_app_lifecycle_handling
  - [ ] require_conflict_resolution_strategy
  - [ ] require_did_update_widget_check
  - [ ] require_late_initialization_in_init_state
  - [ ] require_resume_state_refresh

#### structure_rules.dart
  - [ ] avoid_barrel_files
  - [ ] avoid_classes_with_only_static_members
  - [ ] avoid_global_state
  - [ ] avoid_hardcoded_colors
  - [ ] avoid_importing_entrypoint_exports
  - [ ] avoid_local_functions
  - [ ] avoid_long_functions
  - [ ] avoid_long_length_files
  - [ ] avoid_long_length_test_files
  - [ ] avoid_long_parameter_list
  - [ ] avoid_medium_length_files
  - [ ] avoid_medium_length_test_files
  - [ ] avoid_setters_without_getters
  - [ ] avoid_unused_generics
  - [ ] avoid_very_long_length_files
  - [ ] avoid_very_long_length_test_files
  - [ ] limit_max_imports
  - [ ] prefer_abstract_final_static_class
  - [ ] prefer_constructors_first
  - [ ] prefer_constructors_over_static_methods
  - [ ] prefer_deferred_imports
  - [ ] prefer_extension_methods
  - [ ] prefer_extension_over_utility_class
  - [ ] prefer_extension_type_for_wrapper
  - [ ] prefer_factory_before_named
  - [ ] prefer_function_over_static_method
  - [ ] prefer_getters_before_setters
  - [ ] prefer_import_over_part
  - [ ] prefer_mixin_over_abstract
  - [ ] prefer_named_boolean_parameters
  - [ ] prefer_named_imports
  - [ ] prefer_named_parameters
  - [ ] prefer_overrides_last
  - [ ] prefer_part_over_import
  - [ ] prefer_record_over_tuple_class
  - [ ] prefer_sealed_classes
  - [ ] prefer_sealed_for_state
  - [ ] prefer_small_length_files
  - [ ] prefer_small_length_test_files
  - [ ] prefer_sorted_parameters
  - [ ] prefer_static_before_instance
  - [ ] prefer_static_class
  - [ ] prefer_static_method
  - [ ] prefer_static_method_over_function

#### code_quality_avoid_rules.dart
  - [ ] avoid_accessing_collections_by_constant_index
  - [ ] avoid_async_call_in_sync_function
  - [ ] avoid_contradictory_expressions
  - [ ] avoid_default_tostring
  - [ ] avoid_deprecated_usage
  - [ ] avoid_duplicate_constant_values
  - [ ] avoid_duplicate_string_literals
  - [ ] avoid_duplicate_string_literals_pair
  - [ ] avoid_enum_values_by_index
  - [ ] avoid_expensive_log_string_construction
  - [ ] avoid_identical_exception_handling_blocks
  - [ ] avoid_ignoring_return_values
  - [ ] avoid_incorrect_uri
  - [ ] avoid_missed_calls
  - [ ] avoid_missing_completer_stack_trace
  - [ ] avoid_missing_interpolation
  - [ ] avoid_nested_extension_types
  - [ ] avoid_passing_self_as_argument
  - [ ] avoid_positional_boolean_parameters
  - [ ] avoid_recursive_calls
  - [ ] avoid_recursive_tostring
  - [ ] avoid_referencing_discarded_variables
  - [ ] avoid_shadowed_extension_methods
  - [ ] avoid_similar_names
  - [ ] avoid_slow_collection_methods
  - [ ] banned_identifier_usage
  - [ ] missing_use_result_annotation
  - [ ] use_specific_deprecation

#### code_quality_control_flow_rules.dart
  - [ ] avoid_complex_loop_conditions
  - [ ] prefer_specific_cases_first
  - [ ] prefer_switch_expression
  - [ ] prefer_switch_with_enums
  - [ ] prefer_switch_with_sealed_classes

#### code_quality_prefer_rules.dart
  - [ ] pass_correct_accepted_type
  - [ ] pass_optional_argument
  - [ ] prefer_bytes_builder
  - [ ] prefer_extracting_function_callbacks
  - [ ] prefer_for_in
  - [ ] prefer_named_bool_params
  - [ ] prefer_overriding_parent_equality
  - [ ] prefer_pushing_conditional_expressions
  - [ ] prefer_redirecting_superclass_constructor
  - [ ] prefer_shorthands_with_constructors
  - [ ] prefer_shorthands_with_enums
  - [ ] prefer_shorthands_with_static_fields
  - [ ] prefer_single_declaration_per_file
  - [ ] prefer_typedefs_for_callbacks
  - [ ] prefer_unwrapping_future_or
  - [ ] prefer_visible_for_testing_on_members

#### code_quality_variables_rules.dart
  - [ ] avoid_late_final_reassignment
  - [ ] avoid_late_for_nullable
  - [ ] avoid_missing_enum_constant_in_map
  - [ ] avoid_parameter_mutation
  - [ ] avoid_parameter_reassignment
  - [ ] avoid_unassigned_fields
  - [ ] avoid_unassigned_late_fields
  - [ ] avoid_unnecessary_late_fields
  - [ ] avoid_unnecessary_local_late
  - [ ] avoid_unnecessary_nullable_fields
  - [ ] avoid_unnecessary_nullable_parameters
  - [ ] avoid_unnecessary_patterns
  - [ ] avoid_unused_after_null_check
  - [ ] avoid_unused_instances
  - [ ] function_always_returns_null
  - [ ] function_always_returns_same_value
  - [ ] match_base_class_default_value
  - [ ] move_variable_closer_to_its_usage
  - [ ] move_variable_outside_iteration
  - [ ] prefer_late_final
  - [ ] prefer_late_lazy_initialization
  - [ ] use_existing_destructuring
  - [ ] use_existing_variable

#### complexity_rules.dart
  - [ ] avoid_complex_arithmetic_expressions
  - [ ] avoid_complex_conditions
  - [ ] avoid_deep_nesting
  - [ ] avoid_excessive_expressions
  - [ ] avoid_high_cyclomatic_complexity
  - [ ] avoid_immediately_invoked_functions
  - [ ] avoid_multi_assignment
  - [ ] avoid_nested_shorthands
  - [ ] prefer_moving_to_variable

#### freezed_rules.dart
  - [ ] avoid_freezed_any_map_issue
  - [ ] avoid_freezed_for_logic_classes
  - [ ] avoid_freezed_invalid_annotation_target
  - [ ] prefer_freezed_default_values
  - [ ] prefer_freezed_for_data_classes
  - [ ] prefer_freezed_union_types
  - [ ] require_freezed_arrow_syntax
  - [ ] require_freezed_explicit_json
  - [ ] require_freezed_json_converter
  - [ ] require_freezed_lint_package
  - [ ] require_freezed_private_constructor

#### iap_rules.dart
  - [ ] avoid_entitlement_without_server
  - [ ] avoid_purchase_in_sandbox_production
  - [ ] prefer_grace_period_handling
  - [ ] require_price_localization

#### config_rules.dart
  - [ ] avoid_hardcoded_config
  - [ ] avoid_hardcoded_config_test
  - [ ] avoid_mixed_environments
  - [ ] avoid_platform_specific_imports
  - [ ] avoid_string_env_parsing
  - [ ] prefer_compile_time_config
  - [ ] prefer_flavor_configuration
  - [ ] prefer_semver_version
  - [ ] require_config_validation
  - [ ] require_feature_flag_type_safety

#### platform_rules.dart
  - [ ] prefer_platform_widget_adaptive
  - [ ] require_platform_check

#### async_rules.dart
  - [ ] avoid_async_in_build
  - [ ] avoid_dialog_context_after_async
  - [ ] avoid_future_in_build
  - [ ] avoid_future_then_in_async
  - [ ] avoid_multiple_stream_listeners
  - [ ] avoid_nested_futures
  - [ ] avoid_nested_streams_and_futures
  - [ ] avoid_passing_async_when_sync_expected
  - [ ] avoid_sequential_awaits
  - [ ] avoid_stream_in_build
  - [ ] avoid_stream_subscription_in_field
  - [ ] avoid_stream_sync_events
  - [ ] avoid_stream_tostring
  - [ ] avoid_sync_on_every_change
  - [ ] avoid_unassigned_stream_subscriptions
  - [ ] check_mounted_after_async
  - [ ] prefer_assigning_await_expressions
  - [ ] prefer_async_await
  - [ ] prefer_async_init_state
  - [ ] prefer_broadcast_stream
  - [ ] prefer_cancellation_token_pattern
  - [ ] prefer_commenting_future_delayed
  - [ ] prefer_correct_future_return_type
  - [ ] prefer_correct_stream_return_type
  - [ ] prefer_future_wait
  - [ ] prefer_specifying_future_value_type
  - [ ] prefer_stream_distinct
  - [ ] prefer_stream_transformer
  - [ ] prefer_streams_over_polling
  - [ ] require_cancellable_operations
  - [ ] require_completer_error_handling
  - [ ] require_feature_flag_default
  - [ ] require_future_timeout
  - [ ] require_future_wait_error_handling
  - [ ] require_location_timeout
  - [ ] require_mounted_check_after_await
  - [ ] require_network_status_check
  - [ ] require_pending_changes_indicator
  - [ ] require_stream_cancel_on_error
  - [ ] require_stream_controller_close
  - [ ] require_stream_error_handling
  - [ ] require_stream_on_done
  - [ ] require_subscription_composite
  - [ ] require_websocket_message_validation

#### class_constructor_rules.dart
  - [ ] avoid_accessing_other_classes_private_members
  - [ ] avoid_declaring_call_method
  - [ ] avoid_field_initializers_in_const_classes
  - [ ] avoid_generics_shadowing
  - [ ] avoid_incomplete_copy_with
  - [ ] avoid_non_empty_constructor_bodies
  - [ ] avoid_referencing_subclasses
  - [ ] avoid_renaming_representation_getters
  - [ ] avoid_unmarked_public_class
  - [ ] avoid_unused_constructor_parameters
  - [ ] avoid_variable_shadowing
  - [ ] prefer_asserts_in_initializer_lists
  - [ ] prefer_base_class
  - [ ] prefer_const_constructor_declarations
  - [ ] prefer_const_constructors_in_immutables
  - [ ] prefer_factory_constructor
  - [ ] prefer_final_fields
  - [ ] prefer_final_fields_always
  - [ ] prefer_interface_class
  - [ ] prefer_non_const_constructors
  - [ ] prefer_private_extension_type_field
  - [ ] proper_super_calls
  - [ ] require_late_access_check

#### context_rules.dart
  - [ ] avoid_context_across_async
  - [ ] avoid_context_after_await_in_static
  - [ ] avoid_context_dependency_in_callback
  - [ ] avoid_context_in_async_static
  - [ ] avoid_context_in_static_methods
  - [ ] avoid_storing_context
  - [ ] prefer_closest_context
  - [ ] require_context_in_build_descendants
  - [ ] use_closest_build_context

#### documentation_rules.dart
  - [ ] avoid_misleading_documentation
  - [ ] prefer_correct_throws
  - [ ] require_complex_logic_comments
  - [ ] require_deprecation_message
  - [ ] require_example_in_documentation
  - [ ] require_exception_documentation
  - [ ] require_parameter_documentation
  - [ ] require_public_api_documentation
  - [ ] require_return_documentation
  - [ ] verify_documented_parameters_exist

#### naming_style_rules.dart
  - [ ] avoid_non_ascii_symbols
  - [ ] match_class_name_pattern
  - [ ] match_getter_setter_field_names
  - [ ] match_lib_folder_structure
  - [ ] match_positional_field_names_on_assignment
  - [ ] prefer_adjective_bool_getters
  - [ ] prefer_base_prefix
  - [ ] prefer_boolean_prefixes
  - [ ] prefer_boolean_prefixes_for_locals
  - [ ] prefer_boolean_prefixes_for_params
  - [ ] prefer_correct_callback_field_name
  - [ ] prefer_correct_error_name
  - [ ] prefer_correct_handler_name
  - [ ] prefer_correct_identifier_length
  - [ ] prefer_correct_package_name
  - [ ] prefer_correct_setter_parameter_name
  - [ ] prefer_enhanced_enums
  - [ ] prefer_explicit_parameter_names
  - [ ] prefer_extension_suffix
  - [ ] prefer_i_prefix_interfaces
  - [ ] prefer_impl_suffix
  - [ ] prefer_kebab_tag_name
  - [ ] prefer_lowercase_constants
  - [ ] prefer_match_file_name
  - [ ] prefer_mixin_prefix
  - [ ] prefer_named_extensions
  - [ ] prefer_no_getter_prefix
  - [ ] prefer_no_i_prefix_interfaces
  - [ ] prefer_noun_class_names
  - [ ] prefer_prefixed_global_constants
  - [ ] prefer_typedef_for_callbacks
  - [ ] prefer_verb_method_names
  - [ ] prefer_wildcard_for_unused_param

#### performance_rules.dart
  - [ ] avoid_animation_in_large_list
  - [ ] avoid_blocking_database_ui
  - [ ] avoid_blocking_main_thread
  - [ ] avoid_cache_stampede
  - [ ] avoid_calling_of_in_build
  - [ ] avoid_closure_memory_leak
  - [ ] avoid_controller_in_build
  - [ ] avoid_excessive_widget_depth
  - [ ] avoid_expensive_build
  - [ ] avoid_expensive_computation_in_build
  - [ ] avoid_finalizer_misuse
  - [ ] avoid_full_sync_on_every_launch
  - [ ] avoid_global_key_misuse
  - [ ] avoid_json_in_main
  - [ ] avoid_large_list_copy
  - [ ] avoid_memory_intensive_operations
  - [ ] avoid_money_arithmetic_on_double
  - [ ] avoid_object_creation_in_hot_loops
  - [ ] avoid_rebuild_on_scroll
  - [ ] avoid_scroll_listener_in_build
  - [ ] avoid_setstate_in_build
  - [ ] avoid_string_concatenation_loop
  - [ ] avoid_text_span_in_build
  - [ ] avoid_widget_creation_in_loop
  - [ ] prefer_binary_format
  - [ ] prefer_builder_for_conditional
  - [ ] prefer_cached_getter
  - [ ] prefer_compute_for_heavy_work
  - [ ] prefer_disk_cache_for_persistence
  - [ ] prefer_element_rebuild
  - [ ] prefer_image_precache
  - [ ] prefer_inherited_widget_cache
  - [ ] prefer_layout_builder_over_media_query
  - [ ] prefer_lazy_loading_images
  - [ ] prefer_native_file_dialogs
  - [ ] prefer_pool_pattern
  - [ ] prefer_static_const_widgets
  - [ ] prefer_value_listenable_builder
  - [ ] require_dispose_pattern
  - [ ] require_image_cache_management
  - [ ] require_isolate_for_heavy
  - [ ] require_item_extent_for_large_lists
  - [ ] require_keys_in_animated_lists
  - [ ] require_list_preallocate
  - [ ] require_menu_bar_for_desktop
  - [ ] require_repaint_boundary
  - [ ] require_widget_key_strategy
  - [ ] require_window_close_confirmation

#### state_management_rules.dart
  - [ ] avoid_collection_mutating_methods
  - [ ] avoid_global_key_in_build
  - [ ] avoid_setstate_in_large_state_class
  - [ ] avoid_stateful_without_state
  - [ ] avoid_static_state
  - [ ] prefer_immutable_selector_value
  - [ ] prefer_optimistic_updates
  - [ ] require_notify_listeners
  - [ ] require_stream_controller_dispose
  - [ ] require_value_notifier_dispose

#### collection_rules.dart
  - [ ] avoid_collection_equality_checks
  - [ ] avoid_function_literals_in_foreach_calls
  - [ ] avoid_unreachable_for_loop
  - [ ] avoid_unsafe_collection_methods
  - [ ] avoid_unsafe_reduce
  - [ ] map_keys_ordering
  - [ ] prefer_add_all
  - [ ] prefer_asmap_over_indexed_iteration
  - [ ] prefer_constructor_over_literals
  - [ ] prefer_fold_over_reduce
  - [ ] prefer_for_in_over_foreach
  - [ ] prefer_foreach_over_map_entries
  - [ ] prefer_inlined_adds
  - [ ] prefer_iterable_operations
  - [ ] prefer_null_aware_elements
  - [ ] prefer_set_for_lookup
  - [ ] require_key_for_collection

#### equality_rules.dart
  - [ ] no_equal_arguments

#### json_datetime_rules.dart
  - [ ] avoid_datetime_now_in_tests
  - [ ] avoid_not_encodable_in_to_json
  - [ ] prefer_correct_json_casts
  - [ ] prefer_duration_constants
  - [ ] prefer_explicit_json_keys
  - [ ] prefer_iso8601_dates
  - [ ] prefer_json_codegen
  - [ ] prefer_json_serializable
  - [ ] require_json_date_format_consistency
  - [ ] require_json_decode_try_catch
  - [ ] require_json_schema_validation
  - [ ] require_timezone_display

#### money_rules.dart
  - [ ] avoid_double_for_money
  - [ ] require_currency_code_with_amount

#### numeric_literal_rules.dart
  - [ ] no_magic_number
  - [ ] no_magic_number_in_tests
  - [ ] no_magic_string
  - [ ] no_magic_string_in_tests

#### record_pattern_rules.dart
  - [ ] avoid_bottom_type_in_patterns
  - [ ] avoid_bottom_type_in_records
  - [ ] avoid_extensions_on_records
  - [ ] avoid_function_type_in_records
  - [ ] avoid_keywords_in_wildcard_pattern
  - [ ] avoid_long_records
  - [ ] avoid_mixing_named_and_positional_fields
  - [ ] avoid_nested_records
  - [ ] avoid_one_field_records
  - [ ] avoid_positional_record_field_access
  - [ ] avoid_redundant_positional_field_name
  - [ ] avoid_single_field_destructuring
  - [ ] move_records_to_typedefs
  - [ ] prefer_class_destructuring
  - [ ] prefer_pattern_destructuring
  - [ ] prefer_simpler_patterns_null_check
  - [ ] prefer_sorted_pattern_fields
  - [ ] prefer_sorted_record_fields
  - [ ] prefer_wildcard_pattern

#### type_rules.dart
  - [ ] avoid_casting_to_extension_type
  - [ ] avoid_collection_methods_with_unrelated_types
  - [ ] avoid_dynamic_type
  - [ ] avoid_implicitly_nullable_extension_types
  - [ ] avoid_nullable_interpolation
  - [ ] avoid_nullable_parameters_with_default_values
  - [ ] avoid_nullable_tostring
  - [ ] avoid_private_typedef_functions
  - [ ] avoid_shadowing_type_parameters
  - [ ] avoid_unrelated_type_assertions
  - [ ] prefer_correct_type_name
  - [ ] prefer_explicit_function_type
  - [ ] prefer_inline_function_types
  - [ ] prefer_result_type
  - [ ] prefer_type_over_var

#### type_safety_rules.dart
  - [ ] avoid_dynamic_json_access
  - [ ] avoid_dynamic_json_chains
  - [ ] avoid_non_null_assertion
  - [ ] avoid_type_casts
  - [ ] avoid_unrelated_type_casts
  - [ ] avoid_unsafe_cast
  - [ ] prefer_constrained_generics
  - [ ] prefer_explicit_type_arguments
  - [ ] prefer_specific_numeric_types
  - [ ] require_covariant_documentation
  - [ ] require_enum_unknown_value
  - [ ] require_futureor_documentation
  - [ ] require_null_safe_extensions
  - [ ] require_null_safe_json_access
  - [ ] require_safe_json_parsing
  - [ ] require_validator_return_null

#### control_flow_rules.dart
  - [ ] avoid_collapsible_if
  - [ ] avoid_constant_switches
  - [ ] avoid_double_and_int_checks
  - [ ] avoid_if_with_many_branches
  - [ ] avoid_nested_assignments
  - [ ] avoid_nested_conditional_expressions
  - [ ] avoid_nested_switch_expressions
  - [ ] avoid_nested_switches
  - [ ] avoid_nested_try
  - [ ] avoid_unnecessary_conditionals
  - [ ] avoid_unnecessary_if
  - [ ] no_equal_conditions
  - [ ] prefer_conditional_expressions
  - [ ] prefer_correct_switch_length
  - [ ] prefer_if_elements_to_conditional_expressions
  - [ ] prefer_no_continue_statement
  - [ ] prefer_null_aware_method_calls
  - [ ] prefer_returning_condition
  - [ ] prefer_when_guard_over_if

#### error_handling_rules.dart
  - [ ] avoid_assert_in_production
  - [ ] avoid_catch_all
  - [ ] avoid_exception_in_constructor
  - [ ] avoid_generic_exceptions
  - [ ] avoid_losing_stack_trace
  - [ ] avoid_nested_try_statements
  - [ ] avoid_print_error
  - [ ] avoid_uncaught_future_errors
  - [ ] handle_throwing_invocations
  - [ ] prefer_result_pattern
  - [ ] prefer_zone_error_handler
  - [ ] require_app_startup_error_handling
  - [ ] require_async_error_documentation
  - [ ] require_cache_key_determinism
  - [ ] require_error_boundary
  - [ ] require_error_context
  - [ ] require_error_context_in_logs
  - [ ] require_error_handling_graceful
  - [ ] require_error_logging
  - [ ] require_error_message_clarity
  - [ ] require_error_recovery
  - [ ] require_finally_cleanup
  - [ ] require_notification_action_handling
  - [ ] require_permission_permanent_denial_handling

#### exception_rules.dart
  - [ ] avoid_non_final_exception_class_fields
  - [ ] avoid_throw_objects_without_tostring

#### bluetooth_hardware_rules.dart
  - [ ] avoid_bluetooth_scan_without_timeout
  - [ ] prefer_ble_mtu_negotiation
  - [ ] require_audio_focus_handling
  - [ ] require_ble_disconnect_handling
  - [ ] require_bluetooth_state_check
  - [ ] require_geolocator_error_handling
  - [ ] require_geolocator_permission_check
  - [ ] require_geolocator_service_enabled
  - [ ] require_geolocator_stream_cancel
  - [ ] require_qr_permission_check

#### image_rules.dart
  - [ ] avoid_cached_image_unbounded_list
  - [ ] avoid_cached_image_web
  - [ ] avoid_image_picker_large_files
  - [ ] avoid_image_rebuild_on_scroll
  - [ ] prefer_cached_image_cache_manager
  - [ ] prefer_cached_image_fade_animation
  - [ ] prefer_clipboard_feedback
  - [ ] prefer_image_picker_request_full_metadata
  - [ ] prefer_image_size_constraints
  - [ ] prefer_video_loading_placeholder
  - [ ] require_avatar_fallback
  - [ ] require_cached_image_device_pixel_ratio
  - [ ] require_cached_image_dimensions
  - [ ] require_cached_image_error_widget
  - [ ] require_cached_image_placeholder
  - [ ] require_exif_handling
  - [ ] require_image_cache_dimensions
  - [ ] require_image_error_fallback
  - [ ] require_image_loading_placeholder
  - [ ] require_image_memory_cache_limit
  - [ ] require_image_stream_dispose
  - [ ] require_media_loading_state
  - [ ] require_pdf_loading_indicator

#### media_rules.dart
  - [ ] prefer_audio_session_config
  - [ ] prefer_camera_resolution_selection

#### api_network_rules.dart
  - [ ] avoid_cached_image_in_build
  - [ ] avoid_hardcoded_api_urls
  - [ ] avoid_over_fetching
  - [ ] avoid_redundant_requests
  - [ ] avoid_websocket_without_heartbeat
  - [ ] prefer_api_pagination
  - [ ] prefer_batch_requests
  - [ ] prefer_http_connection_reuse
  - [ ] prefer_stale_while_revalidate
  - [ ] prefer_streaming_response
  - [ ] prefer_timeout_on_requests
  - [ ] require_accept_encoding_header
  - [ ] require_analytics_event_naming
  - [ ] require_api_error_mapping
  - [ ] require_api_response_validation
  - [ ] require_api_version_handling
  - [ ] require_cancel_token
  - [ ] require_connectivity_check
  - [ ] require_connectivity_subscription_cancel
  - [ ] require_content_type_check
  - [ ] require_content_type_validation
  - [ ] require_geolocator_timeout
  - [ ] require_http_status_check
  - [ ] require_image_picker_error_handling
  - [ ] require_image_picker_result_handling
  - [ ] require_image_picker_source_choice
  - [ ] require_notification_handler_top_level
  - [ ] require_notification_permission_android13
  - [ ] require_offline_indicator
  - [ ] require_permission_denied_handling
  - [ ] require_permission_rationale
  - [ ] require_permission_status_check
  - [ ] require_request_timeout
  - [ ] require_response_caching
  - [ ] require_retry_logic
  - [ ] require_sqflite_migration
  - [ ] require_sse_subscription_cancel
  - [ ] require_ssl_pinning_sensitive
  - [ ] require_typed_api_response
  - [ ] require_url_launcher_error_handling
  - [ ] require_websocket_error_handling
  - [ ] require_websocket_reconnection

#### connectivity_rules.dart
  - [ ] avoid_connectivity_equals_internet
  - [ ] prefer_connectivity_debounce
  - [ ] prefer_internet_connection_checker
  - [ ] require_connectivity_error_handling
  - [ ] require_connectivity_resume_check
  - [ ] require_connectivity_timeout

#### auto_route_rules.dart
  - [ ] avoid_auto_route_context_navigation
  - [ ] avoid_auto_route_keep_history_misuse
  - [ ] prefer_auto_route_path_params_simple
  - [ ] prefer_auto_route_typed_args
  - [ ] require_auto_route_deep_link_config
  - [ ] require_auto_route_full_hierarchy
  - [ ] require_auto_route_guard_resume

#### bloc_rules.dart
  - [ ] avoid_bloc_business_logic_in_ui
  - [ ] avoid_bloc_context_dependency
  - [ ] avoid_bloc_emit_after_close
  - [ ] avoid_bloc_event_mutation
  - [ ] avoid_bloc_in_bloc
  - [ ] avoid_bloc_listen_in_build
  - [ ] avoid_bloc_public_fields
  - [ ] avoid_bloc_public_methods
  - [ ] avoid_bloc_state_mutation
  - [ ] avoid_cubit_usage
  - [ ] avoid_duplicate_bloc_event_handlers
  - [ ] avoid_existing_instances_in_bloc_provider
  - [ ] avoid_instantiating_in_bloc_value_provider
  - [ ] avoid_large_bloc
  - [ ] avoid_long_event_handlers
  - [ ] avoid_overengineered_bloc_states
  - [ ] avoid_passing_bloc_to_bloc
  - [ ] avoid_passing_build_context_to_blocs
  - [ ] avoid_returning_value_from_cubit_methods
  - [ ] avoid_yield_in_on_event
  - [ ] check_is_not_closed_after_async_gap
  - [ ] emit_new_bloc_state_instances
  - [ ] prefer_bloc_event_suffix
  - [ ] prefer_bloc_extensions
  - [ ] prefer_bloc_hydration
  - [ ] prefer_bloc_listener_for_side_effects
  - [ ] prefer_bloc_state_suffix
  - [ ] prefer_bloc_transform
  - [ ] prefer_copy_with_for_state
  - [ ] prefer_correct_bloc_provider
  - [ ] prefer_cubit_for_simple
  - [ ] prefer_cubit_for_simple_state
  - [ ] prefer_immutable_bloc_events
  - [ ] prefer_immutable_bloc_state
  - [ ] prefer_multi_bloc_provider
  - [ ] prefer_sealed_bloc_events
  - [ ] prefer_sealed_bloc_state
  - [ ] prefer_sealed_events
  - [ ] require_bloc_close
  - [ ] require_bloc_consumer_when_both
  - [ ] require_bloc_error_state
  - [ ] require_bloc_event_sealed
  - [ ] require_bloc_initial_state
  - [ ] require_bloc_loading_state
  - [ ] require_bloc_manual_dispose
  - [ ] require_bloc_observer
  - [ ] require_bloc_repository_abstraction
  - [ ] require_bloc_repository_injection
  - [ ] require_bloc_selector
  - [ ] require_bloc_transformer
  - [ ] require_error_state
  - [ ] require_immutable_bloc_state
  - [ ] require_initial_state

#### dio_rules.dart
  - [ ] avoid_dio_debug_print_production
  - [ ] avoid_dio_form_data_leak
  - [ ] avoid_dio_without_base_url
  - [ ] prefer_dio_base_options
  - [ ] prefer_dio_cancel_token
  - [ ] prefer_dio_over_http
  - [ ] prefer_dio_transformer
  - [ ] require_dio_error_handling
  - [ ] require_dio_interceptor_error_handler
  - [ ] require_dio_response_type
  - [ ] require_dio_retry_interceptor
  - [ ] require_dio_singleton
  - [ ] require_dio_ssl_pinning
  - [ ] require_dio_timeout

#### drift_rules.dart
  - [ ] avoid_drift_close_streams_in_tests
  - [ ] avoid_drift_database_on_main_isolate
  - [ ] avoid_drift_enum_index_reorder
  - [ ] avoid_drift_foreign_key_in_migration
  - [ ] avoid_drift_get_single_without_unique
  - [ ] avoid_drift_lazy_database
  - [ ] avoid_drift_log_statements_production
  - [ ] avoid_drift_missing_updates_param
  - [ ] avoid_drift_nullable_converter_mismatch
  - [ ] avoid_drift_query_in_migration
  - [ ] avoid_drift_raw_sql_interpolation
  - [ ] avoid_drift_replace_without_all_columns
  - [ ] avoid_drift_unsafe_web_storage
  - [ ] avoid_drift_update_without_where
  - [ ] avoid_drift_validate_schema_production
  - [ ] avoid_drift_value_null_vs_absent
  - [ ] avoid_isar_import_with_drift
  - [ ] prefer_drift_batch_operations
  - [ ] prefer_drift_foreign_key_declaration
  - [ ] prefer_drift_isolate_sharing
  - [ ] prefer_drift_use_columns_false
  - [ ] require_await_in_drift_transaction
  - [ ] require_drift_create_all_in_oncreate
  - [ ] require_drift_database_close
  - [ ] require_drift_equals_value
  - [ ] require_drift_foreign_key_pragma
  - [ ] require_drift_onupgrade_handler
  - [ ] require_drift_read_table_or_null
  - [ ] require_drift_reads_from
  - [ ] require_drift_schema_version_bump
  - [ ] require_drift_stream_cancel

#### equatable_rules.dart
  - [ ] avoid_equatable_datetime
  - [ ] avoid_equatable_nested_equality
  - [ ] avoid_mutable_field_in_equatable
  - [ ] list_all_equatable_fields
  - [ ] prefer_equatable_mixin
  - [ ] prefer_equatable_stringify
  - [ ] prefer_immutable_annotation
  - [ ] prefer_record_over_equatable
  - [ ] prefer_unmodifiable_collections
  - [ ] require_copy_with_null_handling
  - [ ] require_deep_equality_collections
  - [ ] require_equatable_copy_with
  - [ ] require_equatable_props_override
  - [ ] require_extend_equatable

#### firebase_rules.dart
  - [ ] avoid_database_in_build
  - [ ] avoid_firebase_realtime_in_build
  - [ ] avoid_firebase_user_data_in_auth
  - [ ] avoid_firestore_in_widget_build
  - [ ] avoid_firestore_unbounded_query
  - [ ] avoid_map_markers_in_build
  - [ ] avoid_secure_storage_on_web
  - [ ] avoid_storing_user_data_in_auth
  - [ ] incorrect_firebase_event_name
  - [ ] incorrect_firebase_parameter_name
  - [ ] prefer_correct_topics
  - [ ] prefer_deep_link_auth
  - [ ] prefer_firebase_auth_persistence
  - [ ] prefer_firebase_remote_config_defaults
  - [ ] prefer_firebase_transaction_for_counters
  - [ ] prefer_firestore_batch_write
  - [ ] prefer_marker_clustering
  - [ ] prefer_transaction_for_batch
  - [ ] require_background_message_handler
  - [ ] require_crashlytics_user_id
  - [ ] require_database_index
  - [ ] require_database_migration
  - [ ] require_fcm_token_refresh_handler
  - [ ] require_firebase_app_check
  - [ ] require_firebase_app_check_production
  - [ ] require_firebase_composite_index
  - [ ] require_firebase_email_enumeration_protection
  - [ ] require_firebase_error_handling
  - [ ] require_firebase_init_before_use
  - [ ] require_firebase_offline_persistence
  - [ ] require_firebase_reauthentication
  - [ ] require_firebase_token_refresh
  - [ ] require_firestore_index
  - [ ] require_map_idle_callback

#### flame_rules.dart
  - [ ] avoid_creating_vector_in_update
  - [ ] avoid_redundant_async_on_load

#### flutter_hooks_rules.dart
  - [ ] avoid_conditional_hooks
  - [ ] avoid_hooks_outside_build
  - [ ] avoid_misused_hooks
  - [ ] avoid_unnecessary_hook_widgets
  - [ ] prefer_use_callback

#### geolocator_rules.dart
  - [ ] avoid_continuous_location_updates
  - [ ] prefer_geocoding_cache
  - [ ] prefer_geolocation_coarse_location
  - [ ] require_geolocator_battery_awareness

#### get_it_rules.dart
  - [ ] avoid_getit_in_build
  - [ ] prefer_injectable_package
  - [ ] require_getit_dispose_registration
  - [ ] require_getit_registration_order
  - [ ] require_getit_reset_in_tests

#### getx_rules.dart
  - [ ] always_remove_getx_listener
  - [ ] avoid_get_find_in_build
  - [ ] avoid_getx_build_context_bypass
  - [ ] avoid_getx_context_outside_widget
  - [ ] avoid_getx_dialog_snackbar_in_controller
  - [ ] avoid_getx_global_navigation
  - [ ] avoid_getx_global_state
  - [ ] avoid_getx_rx_inside_build
  - [ ] avoid_getx_rx_nested_obs
  - [ ] avoid_getx_static_context
  - [ ] avoid_getx_static_get
  - [ ] avoid_mutable_rx_variables
  - [ ] avoid_obs_outside_controller
  - [ ] avoid_tight_coupling_with_getx
  - [ ] dispose_getx_fields
  - [ ] prefer_getx_builder
  - [ ] prefer_getx_builder_over_obx
  - [ ] proper_getx_super_calls
  - [ ] require_getx_binding
  - [ ] require_getx_binding_routes
  - [ ] require_getx_controller_dispose
  - [ ] require_getx_lazy_put
  - [ ] require_getx_permanent_cleanup
  - [ ] require_getx_worker_dispose

#### graphql_rules.dart
  - [ ] avoid_graphql_string_queries

#### hive_rules.dart
  - [ ] avoid_hive_binary_storage
  - [ ] avoid_hive_box_name_collision
  - [ ] avoid_hive_datetime_local
  - [ ] avoid_hive_field_index_reuse
  - [ ] avoid_hive_large_single_entry
  - [ ] avoid_hive_synchronous_in_ui
  - [ ] avoid_hive_type_modification
  - [ ] prefer_hive_compact
  - [ ] prefer_hive_compact_periodically
  - [ ] prefer_hive_encryption
  - [ ] prefer_hive_value_listenable
  - [ ] prefer_hive_web_aware
  - [ ] prefer_lazy_box_for_large
  - [ ] require_hive_adapter_registration_order
  - [ ] require_hive_box_close
  - [ ] require_hive_database_close
  - [ ] require_hive_encryption_key_secure
  - [ ] require_hive_field_default_value
  - [ ] require_hive_initialization
  - [ ] require_hive_migration_strategy
  - [ ] require_hive_nested_object_adapter
  - [ ] require_hive_type_adapter
  - [ ] require_hive_type_id_management
  - [ ] require_type_adapter_registration

#### isar_rules.dart
  - [ ] avoid_cached_isar_stream
  - [ ] avoid_isar_clear_in_production
  - [ ] avoid_isar_embedded_large_objects
  - [ ] avoid_isar_enum_field
  - [ ] avoid_isar_float_equality_queries
  - [ ] avoid_isar_schema_breaking_changes
  - [ ] avoid_isar_string_contains_without_index
  - [ ] avoid_isar_transaction_nesting
  - [ ] avoid_isar_web_limitations
  - [ ] prefer_isar_async_writes
  - [ ] prefer_isar_batch_operations
  - [ ] prefer_isar_composite_index
  - [ ] prefer_isar_for_complex_queries
  - [ ] prefer_isar_index_for_queries
  - [ ] prefer_isar_lazy_links
  - [ ] prefer_isar_query_stream
  - [ ] require_isar_close_on_dispose
  - [ ] require_isar_collection_annotation
  - [ ] require_isar_id_field
  - [ ] require_isar_inspector_debug_only
  - [ ] require_isar_links_load

#### package_specific_rules.dart
  - [ ] avoid_app_links_sensitive_params
  - [ ] avoid_image_picker_quick_succession
  - [ ] avoid_openai_key_in_code
  - [ ] avoid_webview_file_access
  - [ ] prefer_geolocator_distance_filter
  - [ ] prefer_image_picker_max_dimensions
  - [ ] require_analytics_error_handling
  - [ ] require_apple_signin_nonce
  - [ ] require_calendar_timezone_handling
  - [ ] require_envied_obfuscation
  - [ ] require_google_fonts_fallback
  - [ ] require_google_signin_error_handling
  - [ ] require_keyboard_visibility_dispose
  - [ ] require_openai_error_handling
  - [ ] require_speech_stop_on_dispose
  - [ ] require_svg_error_handler
  - [ ] require_url_launcher_mode
  - [ ] require_webview_ssl_error_handling

#### provider_rules.dart
  - [ ] avoid_change_notifier_in_widget
  - [ ] avoid_instantiating_in_value_provider
  - [ ] avoid_nested_providers
  - [ ] avoid_provider_in_init_state
  - [ ] avoid_provider_in_widget
  - [ ] avoid_provider_of_in_build
  - [ ] avoid_provider_recreate
  - [ ] avoid_provider_value_rebuild
  - [ ] avoid_watch_in_callbacks
  - [ ] dispose_provided_instances
  - [ ] dispose_provider_instances
  - [ ] prefer_change_notifier_proxy
  - [ ] prefer_change_notifier_proxy_provider
  - [ ] prefer_consumer_over_provider_of
  - [ ] prefer_context_read_in_callbacks
  - [ ] prefer_multi_provider
  - [ ] prefer_nullable_provider_types
  - [ ] prefer_provider_extensions
  - [ ] prefer_proxy_provider
  - [ ] prefer_selector_over_consumer
  - [ ] prefer_selector_widget
  - [ ] require_multi_provider
  - [ ] require_provider_dispose
  - [ ] require_provider_generic_type
  - [ ] require_provider_update_should_notify
  - [ ] require_update_callback
  - [ ] require_update_should_notify

#### qr_scanner_rules.dart
  - [ ] avoid_qr_scanner_always_active
  - [ ] require_qr_content_validation
  - [ ] require_qr_scan_feedback

#### riverpod_rules.dart
  - [ ] avoid_circular_provider_deps
  - [ ] avoid_global_riverpod_providers
  - [ ] avoid_listen_in_async
  - [ ] avoid_notifier_constructors
  - [ ] avoid_nullable_async_value_pattern
  - [ ] avoid_ref_in_build_body
  - [ ] avoid_ref_in_dispose
  - [ ] avoid_ref_inside_state_dispose
  - [ ] avoid_ref_read_inside_build
  - [ ] avoid_ref_watch_outside_build
  - [ ] avoid_riverpod_for_network_only
  - [ ] avoid_riverpod_navigation
  - [ ] avoid_riverpod_notifier_in_build
  - [ ] avoid_riverpod_state_mutation
  - [ ] avoid_riverpod_string_provider_name
  - [ ] avoid_unnecessary_consumer_widgets
  - [ ] prefer_consumer_widget
  - [ ] prefer_context_selector
  - [ ] prefer_family_for_params
  - [ ] prefer_immutable_provider_arguments
  - [ ] prefer_notifier_over_state
  - [ ] prefer_riverpod_auto_dispose
  - [ ] prefer_riverpod_code_gen
  - [ ] prefer_riverpod_family_for_params
  - [ ] prefer_riverpod_keep_alive
  - [ ] prefer_riverpod_select
  - [ ] prefer_select_for_partial
  - [ ] require_async_value_order
  - [ ] require_auto_dispose
  - [ ] require_error_handling_in_async
  - [ ] require_flutter_riverpod_not_riverpod
  - [ ] require_flutter_riverpod_package
  - [ ] require_provider_scope
  - [ ] require_riverpod_async_value_guard
  - [ ] require_riverpod_error_handling
  - [ ] require_riverpod_lint
  - [ ] use_ref_and_state_synchronously
  - [ ] use_ref_read_synchronously

#### rxdart_rules.dart
  - [ ] avoid_behavior_subject_last_value
  - [ ] prefer_rxdart_for_complex_streams

#### shared_preferences_rules.dart
  - [ ] avoid_auth_state_in_prefs
  - [ ] avoid_prefs_for_large_data
  - [ ] avoid_shared_prefs_in_isolate
  - [ ] avoid_shared_prefs_large_data
  - [ ] avoid_shared_prefs_sensitive_data
  - [ ] avoid_shared_prefs_sync_race
  - [ ] prefer_encrypted_prefs
  - [ ] prefer_shared_prefs_async_api
  - [ ] prefer_typed_prefs_wrapper
  - [ ] require_shared_prefs_key_constants
  - [ ] require_shared_prefs_null_handling
  - [ ] require_shared_prefs_prefix

#### sqflite_rules.dart
  - [ ] avoid_sqflite_type_mismatch
  - [ ] prefer_sqflite_encryption
  - [ ] require_sqflite_index_for_queries

#### supabase_rules.dart
  - [ ] avoid_supabase_anon_key_in_code
  - [ ] require_supabase_error_handling
  - [ ] require_supabase_realtime_unsubscribe

#### url_launcher_rules.dart
  - [ ] avoid_url_launcher_simulator_tests
  - [ ] prefer_url_launcher_fallback
  - [ ] require_url_launcher_can_launch_check

#### workmanager_rules.dart
  - [ ] require_workmanager_constraints
  - [ ] require_workmanager_for_background
  - [ ] require_workmanager_result_return

#### android_rules.dart
  - [ ] avoid_android_cleartext_traffic
  - [ ] avoid_android_task_affinity_default
  - [ ] prefer_foreground_service_android
  - [ ] prefer_pending_intent_flags
  - [ ] require_android_12_splash
  - [ ] require_android_backup_rules
  - [ ] require_android_permission_request
  - [ ] require_backup_exclusion

#### ios_capabilities_permissions_rules.dart
  - [ ] require_ios_accessibility_labels
  - [ ] require_ios_accessibility_large_text
  - [ ] require_ios_app_clip_size_limit
  - [ ] require_ios_app_group_capability
  - [ ] require_ios_app_tracking_transparency
  - [ ] require_ios_background_audio_capability
  - [ ] require_ios_background_mode
  - [ ] require_ios_background_refresh_declaration
  - [ ] require_ios_biometric_fallback
  - [ ] require_ios_callkit_integration
  - [ ] require_ios_carplay_setup
  - [ ] require_ios_face_id_usage_description
  - [ ] require_ios_healthkit_authorization
  - [ ] require_ios_live_activities_setup
  - [ ] require_ios_local_notification_permission
  - [ ] require_ios_nfc_capability_check
  - [ ] require_ios_pasteboard_privacy_handling
  - [ ] require_ios_permission_description
  - [ ] require_ios_photo_library_add_usage
  - [ ] require_ios_photo_library_limited_access
  - [ ] require_ios_privacy_manifest
  - [ ] require_ios_promotion_display_support
  - [ ] require_ios_push_notification_capability
  - [ ] require_ios_quick_note_awareness
  - [ ] require_ios_share_sheet_uti_declaration
  - [ ] require_ios_siri_intent_definition
  - [ ] require_ios_voiceover_gesture_compatibility
  - [ ] require_ios_widget_extension_capability

#### ios_platform_lifecycle_rules.dart
  - [ ] avoid_ios_13_deprecations
  - [ ] avoid_ios_battery_drain_patterns
  - [ ] avoid_ios_continuous_location_tracking
  - [ ] avoid_ios_debug_code_in_release
  - [ ] avoid_ios_deprecated_uikit
  - [ ] avoid_ios_force_unwrap_in_callbacks
  - [ ] avoid_ios_hardcoded_bundle_id
  - [ ] avoid_ios_hardcoded_device_model
  - [ ] avoid_ios_hardcoded_keyboard_height
  - [ ] avoid_ios_in_app_browser_for_auth
  - [ ] avoid_ios_misleading_push_notifications
  - [ ] avoid_ios_simulator_only_code
  - [ ] avoid_ios_wifi_only_assumption
  - [ ] avoid_long_running_isolates
  - [ ] avoid_notification_spam
  - [ ] prefer_background_sync
  - [ ] prefer_delayed_permission_prompt
  - [ ] prefer_ios_app_intents_framework
  - [ ] prefer_ios_context_menu
  - [ ] prefer_ios_handoff_support
  - [ ] prefer_ios_spotlight_indexing
  - [ ] prefer_ios_storekit2
  - [ ] require_ios_age_rating_consideration
  - [ ] require_ios_app_review_prompt_timing
  - [ ] require_ios_data_protection
  - [ ] require_ios_database_conflict_resolution
  - [ ] require_ios_deployment_target_consistency
  - [ ] require_ios_dynamic_island_safe_zones
  - [ ] require_ios_entitlements
  - [ ] require_ios_focus_mode_awareness
  - [ ] require_ios_icloud_kvstore_limitations
  - [ ] require_ios_keychain_for_credentials
  - [ ] require_ios_keychain_sync_awareness
  - [ ] require_ios_launch_storyboard
  - [ ] require_ios_low_power_mode_handling
  - [ ] require_ios_method_channel_cleanup
  - [ ] require_ios_minimum_version_check
  - [ ] require_ios_multitasking_support
  - [ ] require_ios_orientation_handling
  - [ ] require_ios_receipt_validation
  - [ ] require_ios_review_prompt_frequency
  - [ ] require_ios_scene_delegate_awareness
  - [ ] require_ios_version_check
  - [ ] require_notification_for_long_tasks
  - [ ] require_purchase_restoration
  - [ ] require_purchase_verification
  - [ ] require_sync_error_recovery

#### ios_ui_security_rules.dart
  - [ ] avoid_ios_hardcoded_status_bar
  - [ ] prefer_cupertino_for_ios
  - [ ] prefer_ios_haptic_feedback
  - [ ] prefer_ios_safe_area
  - [ ] require_apple_sign_in
  - [ ] require_ios_ats_exception_documentation
  - [ ] require_ios_certificate_pinning
  - [ ] require_ios_keychain_accessibility
  - [ ] require_ios_universal_links_domain_matching

#### linux_rules.dart
  - [ ] avoid_hardcoded_unix_paths
  - [ ] avoid_sudo_shell_commands
  - [ ] avoid_x11_only_assumptions
  - [ ] prefer_xdg_directory_convention
  - [ ] require_linux_font_fallback

#### macos_rules.dart
  - [ ] avoid_macos_catalyst_unsupported_apis
  - [ ] avoid_macos_deprecated_security_apis
  - [ ] avoid_macos_full_disk_access
  - [ ] avoid_macos_hardened_runtime_violations
  - [ ] prefer_macos_keyboard_shortcuts
  - [ ] prefer_macos_menu_bar_integration
  - [ ] require_macos_app_transport_security
  - [ ] require_macos_entitlements
  - [ ] require_macos_file_access_intent
  - [ ] require_macos_hardened_runtime
  - [ ] require_macos_notarization_ready
  - [ ] require_macos_sandbox_entitlements
  - [ ] require_macos_sandbox_exceptions
  - [ ] require_macos_window_restoration
  - [ ] require_macos_window_size_constraints

#### web_rules.dart
  - [ ] avoid_js_rounded_ints
  - [ ] avoid_platform_channel_on_web
  - [ ] avoid_web_only_dependencies
  - [ ] prefer_csrf_protection
  - [ ] prefer_deferred_loading_web
  - [ ] prefer_js_interop_over_dart_js
  - [ ] prefer_url_strategy_for_web
  - [ ] require_cors_handling
  - [ ] require_web_renderer_awareness

#### windows_rules.dart
  - [ ] avoid_forward_slash_path_assumption
  - [ ] avoid_hardcoded_drive_letters
  - [ ] avoid_max_path_risk
  - [ ] require_windows_single_instance_check

#### db_yield_rules.dart
  - [ ] avoid_return_await_db
  - [ ] require_yield_after_db_write
  - [ ] suggest_yield_after_db_read

#### file_handling_rules.dart
  - [ ] avoid_loading_full_pdf_in_memory
  - [ ] avoid_sqflite_read_all_columns
  - [ ] avoid_sqflite_reserved_words
  - [ ] prefer_sqflite_batch
  - [ ] prefer_sqflite_column_constants
  - [ ] prefer_sqflite_singleton
  - [ ] prefer_streaming_for_large_files
  - [ ] require_file_exists_check
  - [ ] require_file_path_sanitization
  - [ ] require_graphql_error_handling
  - [ ] require_pdf_error_handling
  - [ ] require_sqflite_close
  - [ ] require_sqflite_error_handling
  - [ ] require_sqflite_transaction
  - [ ] require_sqflite_whereargs

#### memory_management_rules.dart
  - [ ] avoid_capturing_this_in_callbacks
  - [ ] avoid_expando_circular_references
  - [ ] avoid_large_isolate_communication
  - [ ] avoid_large_objects_in_state
  - [ ] avoid_retaining_disposed_widgets
  - [ ] avoid_unbounded_cache_growth
  - [ ] prefer_lru_cache
  - [ ] prefer_weak_references
  - [ ] prefer_weak_references_for_cache
  - [ ] require_cache_eviction_policy
  - [ ] require_cache_expiration
  - [ ] require_cache_key_uniqueness
  - [ ] require_expando_cleanup
  - [ ] require_image_disposal

#### resource_management_rules.dart
  - [ ] avoid_image_picker_without_source
  - [ ] prefer_coarse_location_when_sufficient
  - [ ] prefer_geolocator_accuracy_appropriate
  - [ ] prefer_geolocator_last_known
  - [ ] prefer_image_picker_multi_selection
  - [ ] prefer_using_for_temp_resources
  - [ ] require_camera_dispose
  - [ ] require_database_close
  - [ ] require_file_close_in_finally
  - [ ] require_http_client_close
  - [ ] require_image_compression
  - [ ] require_isolate_kill
  - [ ] require_native_resource_cleanup
  - [ ] require_platform_channel_cleanup
  - [ ] require_websocket_close

#### crypto_rules.dart
  - [ ] avoid_deprecated_crypto_algorithms
  - [ ] avoid_hardcoded_encryption_keys
  - [ ] require_secure_key_generation

#### permission_rules.dart
  - [ ] avoid_permission_handler_null_safety
  - [ ] avoid_permission_request_loop
  - [ ] prefer_image_cropping
  - [ ] prefer_permission_minimal_request
  - [ ] prefer_permission_request_in_context
  - [ ] require_camera_permission_check
  - [ ] require_location_permission_rationale
  - [ ] require_permission_lifecycle_observer

#### security_auth_storage_rules.dart
  - [ ] avoid_auth_in_query_params
  - [ ] avoid_encryption_key_in_memory
  - [ ] avoid_hardcoded_credentials
  - [ ] avoid_jwt_decode_client
  - [ ] avoid_secure_storage_large_data
  - [ ] avoid_sensitive_data_in_clipboard
  - [ ] avoid_storing_passwords
  - [ ] avoid_storing_sensitive_unencrypted
  - [ ] prefer_biometric_protection
  - [ ] prefer_local_auth
  - [ ] prefer_oauth_pkce
  - [ ] prefer_root_detection
  - [ ] prefer_webview_sandbox
  - [ ] prefer_whitelist_validation
  - [ ] require_auth_check
  - [ ] require_biometric_fallback
  - [ ] require_clipboard_paste_validation
  - [ ] require_data_encryption
  - [ ] require_keychain_access
  - [ ] require_logout_cleanup
  - [ ] require_multi_factor
  - [ ] require_secure_password_field
  - [ ] require_secure_storage
  - [ ] require_secure_storage_auth_data
  - [ ] require_secure_storage_error_handling
  - [ ] require_secure_storage_for_auth
  - [ ] require_session_timeout
  - [ ] require_token_refresh
  - [ ] require_webview_user_agent

#### security_network_input_rules.dart
  - [ ] avoid_api_key_in_code
  - [ ] avoid_clipboard_sensitive
  - [ ] avoid_dynamic_code_loading
  - [ ] avoid_dynamic_sql
  - [ ] avoid_eval_like_patterns
  - [ ] avoid_external_storage_sensitive
  - [ ] avoid_generic_key_in_url
  - [ ] avoid_hardcoded_signing_config
  - [ ] avoid_ignoring_ssl_errors
  - [ ] avoid_logging_sensitive_data
  - [ ] avoid_path_traversal
  - [ ] avoid_redirect_injection
  - [ ] avoid_screenshot_sensitive
  - [ ] avoid_stack_trace_in_production
  - [ ] avoid_token_in_url
  - [ ] avoid_unnecessary_to_list
  - [ ] avoid_unsafe_deserialization
  - [ ] avoid_unverified_native_library
  - [ ] avoid_user_controlled_urls
  - [ ] avoid_webview_cors_issues
  - [ ] avoid_webview_insecure_content
  - [ ] avoid_webview_javascript_enabled
  - [ ] prefer_data_masking
  - [ ] prefer_html_escape
  - [ ] prefer_typed_data
  - [ ] prefer_webview_javascript_disabled
  - [ ] require_catch_logging
  - [ ] require_certificate_pinning
  - [ ] require_deep_link_validation
  - [ ] require_https_only_test
  - [ ] require_input_sanitization
  - [ ] require_input_validation
  - [ ] require_url_validation
  - [ ] require_webview_error_handling

#### formatting_rules.dart
  - [ ] enforce_parameters_ordering
  - [ ] enum_constants_ordering
  - [ ] format_comment_style
  - [ ] prefer_member_ordering
  - [ ] prefer_readable_line_length

#### stylistic_additional_rules.dart
  - [ ] prefer_absolute_imports
  - [ ] prefer_camel_case_method_names
  - [ ] prefer_concatenation_over_interpolation
  - [ ] prefer_concise_variable_names
  - [ ] prefer_descriptive_variable_names
  - [ ] prefer_explicit_boolean_comparison
  - [ ] prefer_explicit_this
  - [ ] prefer_fields_before_methods
  - [ ] prefer_flat_imports
  - [ ] prefer_grouped_imports
  - [ ] prefer_implicit_boolean_comparison
  - [ ] prefer_instance_members_first
  - [ ] prefer_interpolation_over_concatenation
  - [ ] prefer_lower_camel_case_constants
  - [ ] prefer_methods_before_fields
  - [ ] prefer_private_members_first
  - [ ] prefer_public_members_first
  - [ ] prefer_static_members_first
  - [ ] prefer_var_over_explicit_type

#### stylistic_control_flow_rules.dart
  - [ ] avoid_cascade_notation
  - [ ] prefer_await_over_then
  - [ ] prefer_cascade_assignments
  - [ ] prefer_cascade_over_chained
  - [ ] prefer_chained_over_cascade
  - [ ] prefer_default_enum_case
  - [ ] prefer_early_return
  - [ ] prefer_exhaustive_enums
  - [ ] prefer_fire_and_forget
  - [ ] prefer_guard_clauses
  - [ ] prefer_if_else_over_guards
  - [ ] prefer_positive_conditions
  - [ ] prefer_positive_conditions_first
  - [ ] prefer_separate_assignments
  - [ ] prefer_single_exit_point
  - [ ] prefer_switch_statement
  - [ ] prefer_sync_over_async_where_possible
  - [ ] prefer_then_catcherror
  - [ ] prefer_then_over_await

#### stylistic_error_testing_rules.dart
  - [ ] prefer_error_suffix
  - [ ] prefer_exception_suffix
  - [ ] prefer_expect_over_assert_in_tests
  - [ ] prefer_generic_exception
  - [ ] prefer_given_when_then_comments
  - [ ] prefer_grouped_expectations
  - [ ] prefer_on_over_catch
  - [ ] prefer_self_documenting_tests
  - [ ] prefer_single_expectation_per_test
  - [ ] prefer_specific_exceptions
  - [ ] prefer_test_name_descriptive
  - [ ] prefer_test_name_should_when

#### stylistic_null_collection_rules.dart
  - [ ] prefer_addall_over_spread
  - [ ] prefer_collection_if_over_ternary
  - [ ] prefer_explicit_null_assignment
  - [ ] prefer_keys_with_lookup
  - [ ] prefer_late_over_nullable
  - [ ] prefer_map_entries_iteration
  - [ ] prefer_mutable_collections
  - [ ] prefer_null_aware_assignment
  - [ ] prefer_nullable_over_late
  - [ ] prefer_spread_over_addall
  - [ ] prefer_ternary_over_collection_if

#### stylistic_rules.dart
  - [ ] avoid_escaping_inner_quotes
  - [ ] avoid_explicit_type_declaration
  - [ ] avoid_single_cascade_in_expression_statements
  - [ ] avoid_types_on_closure_parameters
  - [ ] prefer_adjacent_strings
  - [ ] prefer_all_named_parameters
  - [ ] prefer_arrow_functions
  - [ ] prefer_block_body_setters
  - [ ] prefer_class_over_record_return
  - [ ] prefer_descriptive_bool_names
  - [ ] prefer_descriptive_bool_names_strict
  - [ ] prefer_doc_comments_over_regular
  - [ ] prefer_doc_curly_apostrophe
  - [ ] prefer_doc_straight_apostrophe
  - [ ] prefer_explicit_null_checks
  - [ ] prefer_explicit_types
  - [ ] prefer_expression_body_getters
  - [ ] prefer_fixme_format
  - [ ] prefer_inline_callbacks
  - [ ] prefer_interpolation_to_compose
  - [ ] prefer_one_widget_per_file
  - [ ] prefer_optional_named_params
  - [ ] prefer_optional_positional_params
  - [ ] prefer_period_after_doc
  - [ ] prefer_positional_bool_params
  - [ ] prefer_private_underscore_prefix
  - [ ] prefer_raw_strings
  - [ ] prefer_relative_imports
  - [ ] prefer_snake_case_files
  - [ ] prefer_todo_format
  - [ ] prefer_trailing_comma_always
  - [ ] prefer_widget_methods_over_classes

#### stylistic_whitespace_constructor_rules.dart
  - [ ] prefer_compact_class_members
  - [ ] prefer_compact_declarations
  - [ ] prefer_constructor_assertion
  - [ ] prefer_constructor_body_assignment
  - [ ] prefer_factory_for_validation
  - [ ] prefer_grouped_by_purpose
  - [ ] prefer_initializing_formals
  - [ ] prefer_no_blank_line_before_return
  - [ ] prefer_no_blank_line_inside_blocks
  - [ ] prefer_required_before_optional
  - [ ] prefer_single_blank_line_max
  - [ ] prefer_super_parameters

#### stylistic_widget_rules.dart
  - [ ] prefer_borderradius_circular
  - [ ] prefer_clip_r_superellipse
  - [ ] prefer_clip_r_superellipse_clipper
  - [ ] prefer_container_over_sizedbox
  - [ ] prefer_edgeinsets_only
  - [ ] prefer_edgeinsets_symmetric
  - [ ] prefer_expanded_over_flexible
  - [ ] prefer_explicit_colors
  - [ ] prefer_flexible_over_expanded
  - [ ] prefer_material_theme_colors
  - [ ] prefer_richtext_over_text_rich
  - [ ] prefer_sizedbox_over_container
  - [ ] prefer_text_rich_over_richtext

#### debug_rules.dart
  - [ ] avoid_unguarded_debug
  - [ ] prefer_commenting_analyzer_ignores
  - [ ] prefer_conditional_logging
  - [ ] prefer_fail_test_case
  - [ ] prefer_log_levels
  - [ ] prefer_log_timestamp
  - [ ] require_log_level_for_production
  - [ ] require_structured_logging

#### test_rules.dart
  - [ ] avoid_async_callback_in_fake_async
  - [ ] avoid_duplicate_test_assertions
  - [ ] avoid_empty_test_groups
  - [ ] avoid_misused_test_matchers
  - [ ] avoid_real_dependencies_in_tests
  - [ ] avoid_screenshot_in_ci
  - [ ] avoid_test_coupling
  - [ ] avoid_test_implementation_details
  - [ ] avoid_test_on_real_device
  - [ ] avoid_test_print_statements
  - [ ] avoid_top_level_members_in_tests
  - [ ] format_test_name
  - [ ] missing_test_assertion
  - [ ] prefer_correct_test_file_name
  - [ ] prefer_descriptive_test_name
  - [ ] prefer_fake_over_mock
  - [ ] prefer_symbol_over_key
  - [ ] prefer_test_data_builder
  - [ ] prefer_test_report
  - [ ] prefer_test_structure
  - [ ] prefer_test_variant
  - [ ] prefer_unique_test_names
  - [ ] require_accessibility_tests
  - [ ] require_animation_tests
  - [ ] require_dispose_verification_tests
  - [ ] require_edge_case_tests
  - [ ] require_integration_test_timeout
  - [ ] require_mock_http_client
  - [ ] require_performance_test
  - [ ] require_scroll_tests
  - [ ] require_test_cleanup
  - [ ] require_test_groups
  - [ ] require_test_isolation
  - [ ] require_test_widget_pump
  - [ ] require_text_input_tests

#### testing_best_practices_rules.dart
  - [ ] avoid_find_all
  - [ ] avoid_find_by_text
  - [ ] avoid_flaky_tests
  - [ ] avoid_hardcoded_delays
  - [ ] avoid_hardcoded_test_delays
  - [ ] avoid_production_config_in_tests
  - [ ] avoid_real_network_calls_in_tests
  - [ ] avoid_real_timer_in_widget_test
  - [ ] avoid_stateful_test_setup
  - [ ] avoid_test_sleep
  - [ ] avoid_vague_test_descriptions
  - [ ] prefer_bloc_test_package
  - [ ] prefer_fake_platform
  - [ ] prefer_matcher_over_equals
  - [ ] prefer_mock_http
  - [ ] prefer_mock_navigator
  - [ ] prefer_mock_verify
  - [ ] prefer_pump_and_settle
  - [ ] prefer_setup_teardown
  - [ ] prefer_single_assertion
  - [ ] prefer_test_find_by_key
  - [ ] require_arrange_act_assert
  - [ ] require_dialog_tests
  - [ ] require_error_case_tests
  - [ ] require_golden_test
  - [ ] require_integration_test_setup
  - [ ] require_mock_verification
  - [ ] require_pump_after_interaction
  - [ ] require_screen_size_tests
  - [ ] require_test_assertions
  - [ ] require_test_description_convention
  - [ ] require_test_documentation
  - [ ] require_test_keys
  - [ ] require_test_setup_teardown

#### accessibility_rules.dart
  - [ ] avoid_auto_play_media
  - [ ] avoid_color_only_indicators
  - [ ] avoid_color_only_meaning
  - [ ] avoid_gesture_only_interactions
  - [ ] avoid_hidden_interactive
  - [ ] avoid_hover_only
  - [ ] avoid_icon_buttons_without_tooltip
  - [ ] avoid_image_buttons_without_tooltip
  - [ ] avoid_merged_semantics_hiding_info
  - [ ] avoid_motion_without_reduce
  - [ ] avoid_redundant_semantics
  - [ ] avoid_semantics_exclusion
  - [ ] avoid_semantics_in_animation
  - [ ] avoid_small_touch_targets
  - [ ] avoid_text_scale_factor_ignore
  - [ ] avoid_time_limits
  - [ ] prefer_adequate_spacing
  - [ ] prefer_announce_for_changes
  - [ ] prefer_explicit_semantics
  - [ ] prefer_external_keyboard
  - [ ] prefer_focus_traversal_order
  - [ ] prefer_large_touch_targets
  - [ ] prefer_merge_semantics
  - [ ] prefer_scalable_text
  - [ ] prefer_semantics_container
  - [ ] prefer_semantics_sort
  - [ ] prefer_show_hide
  - [ ] require_accessible_images
  - [ ] require_avatar_alt_text
  - [ ] require_badge_count_limit
  - [ ] require_badge_semantics
  - [ ] require_button_semantics
  - [ ] require_drag_alternatives
  - [ ] require_error_identification
  - [ ] require_exclude_semantics_justification
  - [ ] require_focus_indicator
  - [ ] require_focus_order
  - [ ] require_heading_hierarchy
  - [ ] require_heading_semantics
  - [ ] require_image_description
  - [ ] require_image_semantics
  - [ ] require_link_distinction
  - [ ] require_live_region
  - [ ] require_minimum_contrast
  - [ ] require_reduced_motion_support
  - [ ] require_semantic_label_icons
  - [ ] require_semantics_label
  - [ ] require_switch_control
  - [ ] require_text_scale_factor_awareness

#### animation_rules.dart
  - [ ] avoid_animation_in_build
  - [ ] avoid_animation_rebuild_waste
  - [ ] avoid_clip_during_animation
  - [ ] avoid_excessive_rebuilds_animation
  - [ ] avoid_hardcoded_duration
  - [ ] avoid_layout_passes
  - [ ] avoid_multiple_animation_controllers
  - [ ] avoid_overlapping_animations
  - [ ] prefer_implicit_animations
  - [ ] prefer_physics_simulation
  - [ ] prefer_spring_animation
  - [ ] prefer_tween_sequence
  - [ ] require_animation_controller_dispose
  - [ ] require_animation_curve
  - [ ] require_animation_status_listener
  - [ ] require_animation_ticker_disposal
  - [ ] require_hero_tag_uniqueness
  - [ ] require_staggered_animation_delays
  - [ ] require_vsync_mixin

#### internationalization_rules.dart
  - [ ] avoid_hardcoded_app_name
  - [ ] avoid_hardcoded_locale
  - [ ] avoid_hardcoded_locale_strings
  - [ ] avoid_hardcoded_strings_in_ui
  - [ ] avoid_manual_date_formatting
  - [ ] avoid_string_concatenation_for_l10n
  - [ ] avoid_string_concatenation_in_ui
  - [ ] avoid_string_concatenation_l10n
  - [ ] avoid_text_in_images
  - [ ] prefer_date_format
  - [ ] prefer_intl_message_description
  - [ ] prefer_intl_name
  - [ ] prefer_number_format
  - [ ] prefer_providing_intl_description
  - [ ] prefer_providing_intl_examples
  - [ ] provide_correct_intl_args
  - [ ] require_intl_args_match
  - [ ] require_intl_currency_format
  - [ ] require_intl_date_format_locale
  - [ ] require_intl_locale_initialization
  - [ ] require_intl_plural_rules
  - [ ] require_locale_aware_formatting
  - [ ] require_number_format_locale
  - [ ] require_plural_handling
  - [ ] require_rtl_layout_support
  - [ ] require_rtl_support

#### navigation_rules.dart
  - [ ] avoid_circular_redirects
  - [ ] avoid_deep_link_sensitive_params
  - [ ] avoid_go_router_inline_creation
  - [ ] avoid_go_router_push_replacement_confusion
  - [ ] avoid_go_router_string_paths
  - [ ] avoid_navigator_context_issue
  - [ ] avoid_navigator_push_unnamed
  - [ ] avoid_nested_navigators_misuse
  - [ ] avoid_nested_routes_without_parent
  - [ ] avoid_pop_without_result
  - [ ] avoid_push_replacement_misuse
  - [ ] prefer_branch_io_or_firebase_links
  - [ ] prefer_go_router_builder
  - [ ] prefer_go_router_extra_typed
  - [ ] prefer_go_router_redirect
  - [ ] prefer_go_router_redirect_auth
  - [ ] prefer_named_routes_for_deep_links
  - [ ] prefer_route_settings_name
  - [ ] prefer_shell_route_for_persistent_ui
  - [ ] prefer_shell_route_shared_layout
  - [ ] prefer_typed_route_params
  - [ ] prefer_url_launcher_uri_over_string
  - [ ] require_auto_route_page_suffix
  - [ ] require_deep_link_fallback
  - [ ] require_deep_link_testing
  - [ ] require_go_router_error_handler
  - [ ] require_go_router_fallback_route
  - [ ] require_go_router_refresh_listenable
  - [ ] require_go_router_typed_params
  - [ ] require_pop_result_type
  - [ ] require_route_guards
  - [ ] require_route_transition_consistency
  - [ ] require_stateful_shell_route_tabs
  - [ ] require_step_count_indicator
  - [ ] require_stepper_validation
  - [ ] require_unknown_route_handler
  - [ ] require_url_launcher_encoding
  - [ ] require_will_pop_scope

#### notification_rules.dart
  - [ ] avoid_notification_payload_sensitive
  - [ ] avoid_notification_same_id
  - [ ] avoid_notification_silent_failure
  - [ ] prefer_local_notification_for_immediate
  - [ ] prefer_notification_custom_sound
  - [ ] prefer_notification_grouping
  - [ ] require_notification_channel_android
  - [ ] require_notification_initialize_per_platform
  - [ ] require_notification_timezone_awareness

#### build_method_rules.dart
  - [ ] avoid_analytics_in_build
  - [ ] avoid_canvas_operations_in_build
  - [ ] avoid_dialog_in_build
  - [ ] avoid_gradient_in_build
  - [ ] avoid_hardcoded_feature_flags
  - [ ] avoid_json_encode_in_build
  - [ ] avoid_snackbar_in_build
  - [ ] prefer_compute_over_isolate_run
  - [ ] prefer_for_loop_in_children
  - [ ] prefer_single_container
  - [ ] prefer_single_setstate

#### dialog_snackbar_rules.dart
  - [ ] avoid_snackbar_queue_buildup
  - [ ] require_dialog_barrier_dismissible
  - [ ] require_dialog_result_handling
  - [ ] require_snackbar_action_for_undo
  - [ ] require_snackbar_duration

#### forms_rules.dart
  - [ ] avoid_clearing_form_on_error
  - [ ] avoid_form_in_alert_dialog
  - [ ] avoid_form_validation_on_change
  - [ ] avoid_form_without_unfocus
  - [ ] avoid_keyboard_overlap
  - [ ] avoid_validation_in_build
  - [ ] prefer_form_bloc_for_complex
  - [ ] prefer_input_formatters
  - [ ] prefer_on_field_submitted
  - [ ] prefer_regex_validation
  - [ ] prefer_text_input_action
  - [ ] require_autofill_hints
  - [ ] require_error_message_context
  - [ ] require_form_auto_validate_mode
  - [ ] require_form_field_controller
  - [ ] require_form_key
  - [ ] require_form_key_in_stateful_widget
  - [ ] require_form_restoration
  - [ ] require_keyboard_action_type
  - [ ] require_keyboard_dismiss_on_scroll
  - [ ] require_keyboard_type
  - [ ] require_secure_keyboard
  - [ ] require_stepper_state_management
  - [ ] require_submit_button_state
  - [ ] require_text_input_type
  - [ ] require_text_overflow_in_row

#### scroll_rules.dart
  - [ ] avoid_excessive_bottom_nav_items
  - [ ] avoid_infinite_scroll_duplicate_requests
  - [ ] avoid_listview_children_for_large_lists
  - [ ] avoid_multiple_autofocus
  - [ ] avoid_nested_scrollables_conflict
  - [ ] avoid_refresh_without_await
  - [ ] avoid_shrink_wrap_expensive
  - [ ] avoid_shrinkwrap_in_scrollview
  - [ ] prefer_cache_extent
  - [ ] prefer_infinite_scroll_preload
  - [ ] prefer_item_extent
  - [ ] prefer_prototype_item
  - [ ] prefer_sliver_for_mixed_scroll
  - [ ] require_add_automatic_keep_alives_off
  - [ ] require_key_for_reorderable
  - [ ] require_pagination_for_large_lists
  - [ ] require_refresh_indicator_on_lists
  - [ ] require_tab_controller_length_sync

#### theming_rules.dart
  - [ ] avoid_elevation_opacity_in_dark
  - [ ] prefer_dark_mode_colors
  - [ ] prefer_high_contrast_mode
  - [ ] prefer_theme_extensions
  - [ ] require_dark_mode_testing
  - [ ] require_semantic_colors

#### ui_ux_rules.dart
  - [ ] avoid_badge_without_meaning
  - [ ] avoid_loading_flash
  - [ ] prefer_adaptive_icons
  - [ ] prefer_avatar_loading_placeholder
  - [ ] prefer_cached_paint_objects
  - [ ] prefer_itemextent_when_known
  - [ ] prefer_master_detail_for_large
  - [ ] prefer_outlined_icons
  - [ ] prefer_skeleton_over_spinner
  - [ ] require_currency_formatting_locale
  - [ ] require_custom_painter_shouldrepaint
  - [ ] require_empty_results_state
  - [ ] require_graphql_operation_names
  - [ ] require_number_formatting_locale
  - [ ] require_pagination_error_recovery
  - [ ] require_pagination_loading_state
  - [ ] require_responsive_breakpoints
  - [ ] require_search_debounce
  - [ ] require_search_loading_indicator
  - [ ] require_tab_state_preservation
  - [ ] require_webview_progress_indicator

#### widget_layout_constraints_rules.dart
  - [ ] avoid_absorb_pointer_misuse
  - [ ] avoid_border_all
  - [ ] avoid_builder_index_out_of_bounds
  - [ ] avoid_deep_widget_nesting
  - [ ] avoid_deeply_nested_widgets
  - [ ] avoid_fixed_dimensions
  - [ ] avoid_fixed_size_in_scaffold_body
  - [ ] avoid_gesture_detector_in_scrollview
  - [ ] avoid_hardcoded_layout_values
  - [ ] avoid_layout_builder_misuse
  - [ ] avoid_misnamed_padding
  - [ ] avoid_nested_scaffolds
  - [ ] avoid_opacity_misuse
  - [ ] avoid_positioned_outside_stack
  - [ ] avoid_repaint_boundary_misuse
  - [ ] avoid_sized_box_expand
  - [ ] avoid_stack_without_positioned
  - [ ] avoid_table_cell_outside_table
  - [ ] avoid_textfield_in_row
  - [ ] avoid_unbounded_constraints
  - [ ] avoid_unconstrained_box_misuse
  - [ ] avoid_unconstrained_dialog_column
  - [ ] avoid_unconstrained_images
  - [ ] avoid_wrapping_in_padding
  - [ ] check_for_equals_in_render_object_setters
  - [ ] consistent_update_render_object
  - [ ] prefer_clip_behavior
  - [ ] prefer_const_border_radius
  - [ ] prefer_const_widgets_in_lists
  - [ ] prefer_correct_edge_insets_constructor
  - [ ] prefer_custom_single_child_layout
  - [ ] prefer_fractional_sizing
  - [ ] prefer_ignore_pointer
  - [ ] prefer_intrinsic_dimensions
  - [ ] prefer_layout_builder_for_constraints
  - [ ] prefer_opacity_widget
  - [ ] prefer_page_storage_key
  - [ ] prefer_positioned_directional
  - [ ] prefer_safe_area_aware
  - [ ] prefer_sliver_app_bar
  - [ ] prefer_spacing_over_sizedbox
  - [ ] prefer_transform_over_container
  - [ ] require_baseline_text_baseline
  - [ ] require_overflow_box_rationale

#### widget_layout_flex_scroll_rules.dart
  - [ ] avoid_expanded_as_spacer
  - [ ] avoid_expanded_outside_flex
  - [ ] avoid_flexible_outside_flex
  - [ ] avoid_layout_builder_in_scrollable
  - [ ] avoid_listview_without_item_extent
  - [ ] avoid_nested_scrollables
  - [ ] avoid_scrollable_in_intrinsic
  - [ ] avoid_shrink_wrap_in_lists
  - [ ] avoid_shrink_wrap_in_scroll
  - [ ] avoid_single_child_column_row
  - [ ] avoid_singlechildscrollview_with_column
  - [ ] avoid_spacer_in_wrap
  - [ ] avoid_unbounded_listview_in_column
  - [ ] prefer_expanded_at_call_site
  - [ ] prefer_find_child_index_callback
  - [ ] prefer_flex_for_complex_layout
  - [ ] prefer_keep_alive
  - [ ] prefer_listview_builder
  - [ ] prefer_sliver_list
  - [ ] prefer_sliver_list_delegate
  - [ ] prefer_sliver_prefix
  - [ ] prefer_using_list_view
  - [ ] prefer_wrap_over_overflow
  - [ ] require_physics_for_nested_scroll
  - [ ] require_scroll_controller
  - [ ] require_scroll_physics

#### widget_lifecycle_rules.dart
  - [ ] always_remove_listener
  - [ ] avoid_build_context_in_providers
  - [ ] avoid_context_in_initstate_dispose
  - [ ] avoid_expensive_did_change_dependencies
  - [ ] avoid_global_keys_in_state
  - [ ] avoid_inherited_widget_in_initstate
  - [ ] avoid_late_context
  - [ ] avoid_mounted_in_setstate
  - [ ] avoid_recursive_widget_calls
  - [ ] avoid_scaffold_messenger_after_await
  - [ ] avoid_set_state_in_dispose
  - [ ] avoid_state_constructors
  - [ ] avoid_stateless_widget_initialized_fields
  - [ ] avoid_undisposed_instances
  - [ ] avoid_unnecessary_overrides_in_state
  - [ ] avoid_unnecessary_setstate
  - [ ] avoid_unnecessary_stateful_widgets
  - [ ] avoid_unremovable_callbacks_in_listeners
  - [ ] avoid_unsafe_setstate
  - [ ] dispose_widget_fields
  - [ ] nullify_after_dispose
  - [ ] pass_existing_future_to_future_builder
  - [ ] pass_existing_stream_to_stream_builder
  - [ ] prefer_widget_state_mixin
  - [ ] require_animation_disposal
  - [ ] require_field_dispose
  - [ ] require_focus_node_dispose
  - [ ] require_init_state_idempotent
  - [ ] require_scroll_controller_dispose
  - [ ] require_should_rebuild
  - [ ] require_super_dispose_call
  - [ ] require_super_init_state_call
  - [ ] require_timer_cancellation
  - [ ] require_widgets_binding_callback

#### widget_patterns_avoid_prefer_rules.dart
  - [ ] avoid_bool_in_widget_constructors
  - [ ] avoid_catching_generic_exception
  - [ ] avoid_double_tap_submit
  - [ ] avoid_duplicate_widget_keys
  - [ ] avoid_find_child_in_build
  - [ ] avoid_fitted_box_for_text
  - [ ] avoid_form_without_key
  - [ ] avoid_gesture_conflict
  - [ ] avoid_gesture_without_behavior
  - [ ] avoid_hardcoded_asset_paths
  - [ ] avoid_hardcoded_text_styles
  - [ ] avoid_icon_size_override
  - [ ] avoid_image_repeat
  - [ ] avoid_image_without_cache
  - [ ] avoid_incorrect_image_opacity
  - [ ] avoid_large_images_in_memory
  - [ ] avoid_late_without_guarantee
  - [ ] avoid_mediaquery_in_build
  - [ ] avoid_missing_image_alt
  - [ ] avoid_multiple_material_apps
  - [ ] avoid_navigation_in_build
  - [ ] avoid_navigator_push_without_route_name
  - [ ] avoid_nullable_widget_methods
  - [ ] avoid_regex_in_loop
  - [ ] avoid_returning_widgets
  - [ ] avoid_service_locator_overuse
  - [ ] avoid_stateful_widget_in_list
  - [ ] avoid_static_route_config
  - [ ] avoid_text_scale_factor
  - [ ] avoid_uncontrolled_text_field
  - [ ] avoid_unnecessary_containers
  - [ ] avoid_unnecessary_gesture_detector
  - [ ] avoid_unrestricted_text_field_length
  - [ ] avoid_unused_callback_parameters
  - [ ] prefer_actions_and_shortcuts
  - [ ] prefer_asset_image_for_local
  - [ ] prefer_cached_network_image
  - [ ] prefer_carousel_view
  - [ ] prefer_const_literals_to_create_immutables
  - [ ] prefer_cursor_for_buttons
  - [ ] prefer_define_hero_tag
  - [ ] prefer_extracting_callbacks
  - [ ] prefer_feature_folder_structure
  - [ ] prefer_fit_cover_for_background
  - [ ] prefer_getter_over_method
  - [ ] prefer_overlay_portal
  - [ ] prefer_safe_area_consumer
  - [ ] prefer_scaffold_messenger_maybeof
  - [ ] prefer_search_anchor
  - [ ] prefer_single_widget_per_file
  - [ ] prefer_split_widget_const
  - [ ] prefer_tap_region_for_dismiss
  - [ ] prefer_text_rich
  - [ ] prefer_utc_datetimes
  - [ ] prefer_widget_private_members

#### widget_patterns_require_rules.dart
  - [ ] prefer_overlay_portal_layout_builder
  - [ ] require_animated_builder_child
  - [ ] require_button_loading_state
  - [ ] require_default_text_style
  - [ ] require_dialog_barrier_consideration
  - [ ] require_disabled_state
  - [ ] require_drag_feedback
  - [ ] require_error_widget
  - [ ] require_form_validation
  - [ ] require_hover_states
  - [ ] require_https_over_http
  - [ ] require_image_dimensions
  - [ ] require_image_error_builder
  - [ ] require_image_picker_permission_android
  - [ ] require_image_picker_permission_ios
  - [ ] require_locale_for_text
  - [ ] require_long_press_callback
  - [ ] require_orientation_handling
  - [ ] require_permission_manifest_android
  - [ ] require_permission_plist_ios
  - [ ] require_placeholder_for_network
  - [ ] require_refresh_indicator
  - [ ] require_rethrow_preserve_stack
  - [ ] require_safe_area_handling
  - [ ] require_text_form_field_in_form
  - [ ] require_text_overflow_handling
  - [ ] require_theme_color_from_scheme
  - [ ] require_url_launcher_queries_android
  - [ ] require_url_launcher_schemes_ios
  - [ ] require_webview_navigation_delegate
  - [ ] require_window_size_constraints
  - [ ] require_wss_over_ws

#### widget_patterns_ux_rules.dart
  - [ ] avoid_brightness_check_for_theme
  - [ ] prefer_action_button_tooltip
  - [ ] prefer_color_scheme_from_seed
  - [ ] prefer_cupertino_for_ios_feel
  - [ ] prefer_keyboard_shortcuts
  - [ ] prefer_rich_text_for_complex
  - [ ] prefer_semantic_widget_names
  - [ ] prefer_system_theme_default
  - [ ] prefer_text_theme


### 2. How quick fixes work in this repo

- Rules extend `SaropaLintRule` (`lib/src/saropa_lint_rule.dart`) and optionally override:

  - `List<SaropaFixGenerator> get fixGenerators => [ ({required CorrectionProducerContext context}) => MyFix(context: context), ];`

- Fix producers extend `SaropaFixProducer` (`lib/src/native/saropa_fix.dart`) and implement:
  - `FixKind get fixKind`
  - `Future<void> compute(ChangeBuilder builder)`

- Reusable bases:
  - `ReplaceNodeFix` (`lib/src/fixes/common/replace_node_fix.dart`)
  - `DeleteNodeFix` (`lib/src/fixes/common/delete_node_fix.dart`)
  - `InsertTextFix` (`lib/src/fixes/common/insert_text_fix.dart`)

**Prohibited: "Insert-TODO" style fixes.** Do not add quick fixes that only insert a `// TODO: ...` comment (or similar) at the violation. They add no value over the lint itself and clutter the fix list. Only implement fixes that make a real code change (replace/delete/insert that resolves or meaningfully addresses the violation).

### 3. High-signal “EASY fix” candidates (deterministic, local edits)

These are rules where the diagnostic points at a narrow AST node and the fix is a one-step replace/delete/insert.

#### A) `structure_rules.dart` (51 rules, 0 fixes)

Already verified in source: it reports on `ImportDirective` / `ExportDirective` / URI literals / parameter tokens for multiple rules.

**EASY:**

- **`avoid_double_slash_imports`**
  - **Reports:** URI `SimpleStringLiteral` in import/export directives.
  - **Fix:** replace string literal value with `value.replaceAll('//', '/')`.

- **`avoid_duplicate_exports`**
  - **Reports:** the duplicate `ExportDirective`.
  - **Fix:** delete the directive.

- **`avoid_duplicate_named_imports`**
  - **Reports:** duplicate `ImportDirective`.
  - **Fix:** delete the directive.

- **`prefer_trailing_underscore_for_unused`**
  - **Reports:** `param.name` token for unused parameters in closures.
  - **Fix:** rename `x` → `x_` (or `_x`) consistently with the rule message.

**MEDIUM/HARD (examples):** `prefer_named_imports`, `prefer_named_parameters`, `prefer_mixin_over_abstract` (may require structural transformation), `avoid_unnecessary_nullable_return_type` (needs semantics).

#### B) `bloc_rules.dart` (54 rules, 0 fixes)

**EASY:**

- **`avoid_bloc_event_in_constructor`**
  - **Reports:** `MethodInvocation` for `add(...)` inside constructor.
  - **Fix:** delete the enclosing `ExpressionStatement` (remove the `add(...)` call statement).

#### C) `performance_rules.dart` (50 rules, 0 fixes)

**EASY:**

- **`prefer_const_widgets`**
  - **Reports:** `InstanceCreationExpression` constructor node.
  - **Fix:** prefix with `const` when safe (similar to existing const-focused fixes).

**MEDIUM:**

- **`avoid_synchronous_file_io`**
  - **Reports:** sync method invocation (`readAsStringSync`, etc.).
  - **Fix option 1:** replace the method name with async version.
  - **Fix option 2:** if in async function, also insert `await ` at the call site (multi-edit).

#### D) `naming_style_rules.dart` (34 rules, 0 fixes)

**EASY (reuse):**

- **`prefer_capitalized_comment_start`**
  - `CapitalizeCommentFix` already exists (`lib/src/fixes/stylistic/capitalize_comment_fix.dart`) and is wired to a stylistic rule.
  - Add `fixGenerators` for this naming rule that returns `CapitalizeCommentFix`.

#### E) `type_rules.dart` (20 rules, 0 fixes)

**EASY:**

- **`prefer_const_declarations`**
  - Reports at the variable name token in a `VariableDeclarationList` with keyword `final`.
  - Fix: replace `final` with `const` on that declaration list.

- **`prefer_final_locals`**
  - Reports at the variable name token for local vars never reassigned.
  - Fix: insert `final` keyword (or replace `var` with `final`) on the declaration list.

### 4. Additional “EASY” buckets for later scanning

These files are high rule-count with 0% fixes and likely contain many deterministic replacements/deletions:

- `code_quality_avoid_rules.dart` (44, 0 fixes) — pragma deletions, unused param renames, crypto algorithm replacement/TODO.
- `firebase_rules.dart` (32, 0 fixes) — often literal/config or API substitutions.
- `drift_rules.dart` (31, 0 fixes) — frequent “prefer X API” patterns.
- `widget_patterns_require_rules.dart` (31, 0 fixes) — many widget substitution fixes can follow patterns already used in widget rules.
- iOS sub-files like `ios_platform_lifecycle_rules.dart` (47, 0 fixes) and `ios_capabilities_permissions_rules.dart` (29, 0 fixes) — many plist/literal transformations.

### 5. Practical ceiling + classification

- **EASY:** deterministic local edit; safe. (Target: hundreds of rules over time.)
- **MEDIUM:** multi-node but deterministic; still safe with careful implementation.
- **HARD/NONE:** ambiguous refactors, project-wide renames, semantics-heavy transformations.

Execution work follows **Part 2 (Checklist)** below.

---

## Part 2 — Checklist

### A. Pre-flight (once)

- [ ] Run `python scripts/publish.py` (audit-only) and record:
  - [ ] quick fix coverage (count + %)
  - [ ] “Files needing quick fixes” top offenders
- [ ] Confirm clean baseline:
  - [ ] `dart analyze --fatal-infos` passes
  - [ ] `dart test` passes
- [ ] Create a working branch for quick fix batches.

### B. Batch workflow (repeat for every fix)

- [ ] Add / update fix producer under `lib/src/fixes/**`
  - [ ] Prefer `ReplaceNodeFix` / `DeleteNodeFix` / `InsertTextFix` for simple edits
  - [ ] Otherwise extend `SaropaFixProducer`
- [ ] Wire the rule to the fix:
  - [ ] Add `fixGenerators` override on the rule class in `lib/src/rules/**`
- [ ] Add fixture showing violation + expected fix outcome (`example*`):
  - [ ] Include `// LINT` marker
- [ ] Add / update test under `test/**` to verify:
  - [ ] fix is offered for the diagnostic
  - [ ] applying fix produces expected output
- [ ] Run:
  - [ ] `dart format .`
  - [ ] `dart analyze --fatal-infos`
  - [ ] `dart test`
- [ ] Re-run `python scripts/publish.py` (audit-only) and confirm fix count increased.

### C. Batch 1 — `structure_rules.dart` (EASY, deterministic)

**File:** `lib/src/rules/structure_rules.dart` (51 rules, 4 fixes)

**Exit criteria:** All 4 fixes have fixtures + tests and audit count increases by 4.

### D. Batch 2 — `bloc_rules.dart` + `performance_rules.dart` (EASY)

**Exit criteria:** +2 fixes, fixtures/tests present, audit count increases by 2.

### E. Batch 3 — naming + type (EASY, high impact)

**Exit criteria:** +3 fixes, fixtures/tests present, audit count increases by 3.

### F. Batch 4 — `code_quality_avoid_rules.dart` (EASY candidates)

**File:** `lib/src/rules/code_quality_avoid_rules.dart` (44 rules, 0 fixes)

**Exit criteria:** +2 to +3 fixes, fixtures/tests present, audit increases accordingly.

### G. Batch 5 — `unnecessary_code_rules.dart` (fill remaining gaps)

**Exit criteria:** +N fixes with tests, audit increases.

### H. Batch 6 — Performance sync I/O (MEDIUM)

- [ ] Fix 2 (optional): also add `await` when legal (multi-edit)

**Exit criteria:** +1 or +2 fixes, fixtures/tests present, audit increases.

### H2. Batch 7 — Control flow, code quality, collection (EASY)

**Exit criteria:** +5 fixes, fixtures/tests present, audit increases.

### H3. Batch 8 — Control flow (more) + exception (EASY)

**Exit criteria:** +3 fixes, tests present, audit increases.

### H4. Batch 9 — Return (EASY)

**Exit criteria:** +1 fix.

### H5. Batch 10 — Control flow, equality, return, error handling, async (EASY)

**Exit criteria:** +10 fixes (9 rules; one rule has 2 fix generators), fixtures/tests present, audit increases.

### H6. Batch 11 — Collection, formatting, code quality, return, complexity (EASY)

**Exit criteria:** +13 fixes, tests in collection/formatting/code_quality/return/complexity test files, audit increases.

### I. After Batch 6

- [ ] Run full audit and record:
  - [ ] new fix count / coverage %
  - [ ] updated worst offending files list
- [ ] Add Batch 7+ for iOS, security, widget patterns/layout based on updated audit deltas.
