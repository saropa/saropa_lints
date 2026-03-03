# bugs/history integration checklist

**Goal: delete each listed file.** To do that, all information in the file must first be integrated into the rest of the project. When integration is complete for a file, delete that file (or archive it). Do not delete a file until its contents have been fully integrated.

**For each file:** (1) Read the file and identify every piece of information that should live elsewhere (rule behavior, known FPs, edge cases, code examples, release notes, etc.). (2) Integrate that information into the appropriate project artifacts: rule DartDoc (known FPs, edge cases); CHANGELOG or CHANGELOG_ARCHIVE (### Fixed / ### Added per affected rule); tests (e.g. test/false_positive_fixes_test.dart or the rule test); fixtures ("good" and "bad" cases); ROADMAP or other docs if the file describes rule status or design. (3) Remove any references to the file from CHANGELOG or elsewhere. (4) Delete the file (or archive it). Then check the box.


**First 10 reviewed (false_positives):** All 10 had fixes already in rule implementations and CHANGELOG_ARCHIVE. Integrated: rule DartDoc exemptions, CHANGELOG [Unreleased] bullet, and FP test groups for avoid_barrel_files and avoid_duplicate_number_elements. History files kept (not deleted) for detail.


<!-- cspell:disable -->
---

## Phase 3: not_viable/roadmap (11 files)

- [ ] bugs/history/not_viable/roadmap/task_??_avoid_any_version.md
- [ ] bugs/history/not_viable/roadmap/task_??_avoid_banned_api.md
- [ ] bugs/history/not_viable/roadmap/task_??_avoid_connectivity_ui_decisions.md
- [ ] bugs/history/not_viable/roadmap/task_??_avoid_dependency_overrides.md
- [ ] bugs/history/not_viable/roadmap/task_??_avoid_firestore_admin_role_overuse.md
- [ ] bugs/history/not_viable/roadmap/task_??_avoid_large_assets_on_web.md
- [ ] bugs/history/not_viable/roadmap/task_??_avoid_large_object_in_state.md
- [ ] bugs/history/not_viable/roadmap/task_??_avoid_pagination_refetch_all.md
- [ ] bugs/history/not_viable/roadmap/task_??_avoid_repeated_widget_creation.md
- [ ] bugs/history/not_viable/roadmap/task_??_avoid_suspicious_global_reference.md
- [ ] bugs/history/not_viable/roadmap/task_??_avoid_unbounded_collections.md

---

## Phase 2: plans (7 files)

- [ ] bugs/history/plans/drift_support_plan.md
- [ ] bugs/history/plans/file_structure.md
- [ ] bugs/history/plans/framework_feature_upgrade_suggestions.md
- [ ] bugs/history/plans/ROADMAP_NATIVE_PLUGIN.md
- [ ] bugs/history/plans/rule_versioning_plan.md
- [ ] bugs/history/plans/task_test_coverage_improvement_plan.md
- [ ] bugs/history/plans/TIER_AND_SEVERITY_ANALYSIS.md

---

## Phase 2: releases (2 files)

- [ ] bugs/history/releases/2026-02-07_v4.12.2_abort_rerun_config.md
- [ ] bugs/history/releases/ci_analyzer_fixes_2026.md

---

## Phase 2: roadmap/summary (5 files)

- [ ] bugs/history/roadmap/README.md
- [ ] bugs/history/roadmap/summary/nine_rules_implemented_2026.md
- [ ] bugs/history/roadmap/summary/roadmap_detail_12_rules_implemented.md
- [ ] bugs/history/roadmap/summary/SUMMARY_18_roadmap_detail_rules_implemented.md
- [ ] bugs/history/roadmap/summary/SUMMARY.md

---

## Phase 2: roadmap/task (plain) (75 files)

- [ ] bugs/history/roadmap/task/task_avoid_cascades.md
- [ ] bugs/history/roadmap/task/task_avoid_cubits.md
- [ ] bugs/history/roadmap/task/task_avoid_expensive_log_string_construction.md
- [ ] bugs/history/roadmap/task/task_avoid_explicit_type_declaration.md
- [ ] bugs/history/roadmap/task/task_avoid_freezed_invalid_annotation_target.md
- [ ] bugs/history/roadmap/task/task_avoid_referencing_subclasses.md
- [ ] bugs/history/roadmap/task/task_avoid_renaming_representation_getters.md
- [ ] bugs/history/roadmap/task/task_avoid_returning_this.md
- [ ] bugs/history/roadmap/task/task_avoid_riverpod_string_provider_name.md
- [ ] bugs/history/roadmap/task/task_avoid_test_on_real_device.md
- [ ] bugs/history/roadmap/task/task_avoid_unnecessary_null_aware_elements.md
- [ ] bugs/history/roadmap/task/task_format_test_name.md
- [ ] bugs/history/roadmap/task/task_prefer_asmap_over_indexed_iteration.md
- [ ] bugs/history/roadmap/task/task_prefer_auto_route_path_params_simple.md
- [ ] bugs/history/roadmap/task/task_prefer_auto_route_typed_args.md
- [ ] bugs/history/roadmap/task/task_prefer_base_prefix.md
- [ ] bugs/history/roadmap/task/task_prefer_biometric_protection.md
- [ ] bugs/history/roadmap/task/task_prefer_bloc_extensions.md
- [ ] bugs/history/roadmap/task/task_prefer_block_body_setters.md
- [ ] bugs/history/roadmap/task/task_prefer_branch_io_or_firebase_links.md
- [ ] bugs/history/roadmap/task/task_prefer_builder_pattern.md
- [ ] bugs/history/roadmap/task/task_prefer_cache_extent.md
- [ ] bugs/history/roadmap/task/task_prefer_cancellation_token_pattern.md
- [ ] bugs/history/roadmap/task/task_prefer_cascade_assignments.md
- [ ] bugs/history/roadmap/task/task_prefer_class_destructuring.md
- [ ] bugs/history/roadmap/task/task_prefer_closest_context.md
- [ ] bugs/history/roadmap/task/task_prefer_compile_time_config.md
- [ ] bugs/history/roadmap/task/task_prefer_conditional_logging.md
- [ ] bugs/history/roadmap/task/task_prefer_connectivity_debounce.md
- [ ] bugs/history/roadmap/task/task_prefer_const_constructor_declarations.md
- [ ] bugs/history/roadmap/task/task_prefer_constructor_over_literals.md
- [ ] bugs/history/roadmap/task/task_prefer_constructors_over_static_methods.md
- [ ] bugs/history/roadmap/task/task_prefer_correct_json_casts.md
- [ ] bugs/history/roadmap/task/task_prefer_correct_throws.md
- [ ] bugs/history/roadmap/task/task_prefer_correct_topics.md
- [ ] bugs/history/roadmap/task/task_prefer_dark_mode_colors.md
- [ ] bugs/history/roadmap/task/task_prefer_deactivate_for_cleanup.md
- [ ] bugs/history/roadmap/task/task_prefer_deep_link_auth.md
- [ ] bugs/history/roadmap/task/task_prefer_disk_cache_for_persistence.md
- [ ] bugs/history/roadmap/task/task_prefer_explicit_null_checks.md
- [ ] bugs/history/roadmap/task/task_prefer_expression_body_getters.md
- [ ] bugs/history/roadmap/task/task_prefer_extension_suffix.md
- [ ] bugs/history/roadmap/task/task_prefer_factory_constructor.md
- [ ] bugs/history/roadmap/task/task_prefer_final_fields_always.md
- [ ] bugs/history/roadmap/task/task_prefer_find_child_index_callback.md
- [ ] bugs/history/roadmap/task/task_prefer_fire_and_forget.md
- [ ] bugs/history/roadmap/task/task_prefer_firebase_transaction_for_counters.md
- [ ] bugs/history/roadmap/task/task_prefer_flavor_configuration.md
- [ ] bugs/history/roadmap/task/task_prefer_flex_for_complex_layout.md
- [ ] bugs/history/roadmap/task/task_prefer_fold_over_reduce.md
- [ ] bugs/history/roadmap/task/task_prefer_foreach_over_map_entries.md
- [ ] bugs/history/roadmap/task/task_prefer_foreach.md
- [ ] bugs/history/roadmap/task/task_prefer_freezed_union_types.md
- [ ] bugs/history/roadmap/task/task_prefer_function_over_static_method.md
- [ ] bugs/history/roadmap/task/task_prefer_geolocator_coarse_location.md
- [ ] bugs/history/roadmap/task/task_prefer_getx_builder_over_obx.md
- [ ] bugs/history/roadmap/task/task_prefer_go_router_builder.md
- [ ] bugs/history/roadmap/task/task_prefer_high_contrast_mode.md
- [ ] bugs/history/roadmap/task/task_prefer_i_prefix_interfaces.md
- [ ] bugs/history/roadmap/task/task_prefer_if_else_over_guards.md
- [ ] bugs/history/roadmap/task/task_prefer_impl_suffix.md
- [ ] bugs/history/roadmap/task/task_prefer_import_over_part.md
- [ ] bugs/history/roadmap/task/task_prefer_layout_builder_for_constraints.md
- [ ] bugs/history/roadmap/task/task_prefer_mixin_prefix.md
- [ ] bugs/history/roadmap/task/task_prefer_no_i_prefix_interfaces.md
- [ ] bugs/history/roadmap/task/task_prefer_non_const_constructors.md
- [ ] bugs/history/roadmap/task/task_prefer_optional_named_params.md
- [ ] bugs/history/roadmap/task/task_prefer_optional_positional_params.md
- [ ] bugs/history/roadmap/task/task_prefer_overrides_last.md
- [ ] bugs/history/roadmap/task/task_prefer_result_type.md
- [ ] bugs/history/roadmap/task/task_prefer_separate_assignments.md
- [ ] bugs/history/roadmap/task/task_prefer_static_method_over_function.md
- [ ] bugs/history/roadmap/task/task_require_auto_route_page_suffix.md
- [ ] bugs/history/roadmap/task/task_require_const_list_items.md
- [ ] bugs/history/roadmap/task/task_require_firebase_reauthentication.md
- [ ] bugs/history/roadmap/task/task_require_firebase_token_refresh.md

---

## Phase 2: roadmap/task_info (50 files)

- [ ] bugs/history/roadmap/task_info/task_??_avoid_bool_in_widget_constructors.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_classes_with_only_static_members.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_double_and_int_checks.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_equals_and_hash_code_on_mutable_classes.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_escaping_inner_quotes.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_field_initializers_in_const_classes.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_function_literals_in_foreach_calls.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_implementing_value_types.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_js_rounded_ints.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_null_checks_in_equality_operators.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_positional_boolean_parameters.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_private_typedef_functions.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_redundant_argument_values.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_redundant_await.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_redundant_null_check.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_returning_null_for_future.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_returning_null_for_void.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_setters_without_getters.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_single_cascade_in_expression_statements.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_unnecessary_containers.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_adjacent_strings.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_adjective_bool_getters.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_asserts_in_initializer_lists.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_const_constructors_in_immutables.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_const_declarations.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_const_literals_to_create_immutables.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_constructors_first.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_expression_function_bodies.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_extension_methods.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_extension_over_utility_class.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_extension_type_for_wrapper.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_final_fields.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_final_locals.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_getters_before_setters.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_if_elements_to_conditional_expressions.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_inlined_adds.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_interpolation_to_compose.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_lowercase_constants.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_mixin_over_abstract.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_named_bool_params.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_noun_class_names.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_null_aware_method_calls.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_raw_strings.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_record_over_tuple_class.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_sealed_classes.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_sealed_for_state.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_static_before_instance.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_verb_method_names.md
- [ ] bugs/history/roadmap/task_info/task_??_require_deprecation_message.md
- [ ] bugs/history/roadmap/task_info/task_??_require_public_api_documentation.md

---

## Phase 2: roadmap/task_octopus (6 files)

- [ ] bugs/history/roadmap/task_octopus/task_??_prefer_batch_requests.md
- [ ] bugs/history/roadmap/task_octopus/task_??_prefer_binary_format.md
- [ ] bugs/history/roadmap/task_octopus/task_??_prefer_infinite_scroll_preload.md
- [ ] bugs/history/roadmap/task_octopus/task_??_prefer_pool_pattern.md
- [ ] bugs/history/roadmap/task_octopus/task_??_require_compression.md
- [ ] bugs/history/roadmap/task_octopus/task_??_require_expando_cleanup.md

---

## Phase 2: roadmap/task_star (7 files)

- [ ] bugs/history/roadmap/task_star/task_?_avoid_deprecated_usage.md
- [ ] bugs/history/roadmap/task_star/task_?_handle_throwing_invocations.md
- [ ] bugs/history/roadmap/task_star/task_?_no_empty_block.md
- [ ] bugs/history/roadmap/task_star/task_?_prefer_form_bloc_for_complex.md
- [ ] bugs/history/roadmap/task_star/task_?_prefer_local_notification_for_immediate.md
- [ ] bugs/history/roadmap/task_star/task_?_prefer_master_detail_for_large.md
- [ ] bugs/history/roadmap/task_star/task_?_require_auto_route_guard_resume.md

---

## Phase 2: roadmap/task_warning (62 files)

- [ ] bugs/history/roadmap/task_warning/task_??_avoid_accessing_other_classes_private_members.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_auto_route_context_navigation.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_auto_route_keep_history_misuse.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_behavior_subject_last_value.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_cache_stampede.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_cached_image_web.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_clip_during_animation.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_closure_capture_leaks.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_collection_mutating_methods.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_connectivity_equals_internet.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_deep_nesting.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_dynamic_calls.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_entitlement_without_server.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_equatable_nested_equality.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_expensive_did_change_dependencies.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_firebase_user_data_in_auth.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_form_validation_on_change.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_freezed_any_map_issue.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_getx_rx_nested_obs.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_high_cyclomatic_complexity.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_hive_datetime_local.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_hive_large_single_entry.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_hive_type_modification.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_missing_controller.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_missing_tr_on_strings.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_missing_tr.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_multiple_animation_controllers.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_permission_request_loop.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_platform_specific_imports.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_remember_me_insecure.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_return_await_db.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_secure_storage_in_background.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_shadowing_type_parameters.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_shared_prefs_sync_race.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_stack_trace_in_production.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_string_env_parsing.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_suspicious_super_overrides.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_unused_constructor_parameters.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_unused_local_variable.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_url_launcher_sandbox_issues.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_void_async.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_webview_cors_issues.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_webview_local_storage_access.md
- [ ] bugs/history/roadmap/task_warning/task_??_banned_usage.md
- [ ] bugs/history/roadmap/task_warning/task_??_prefer_csrf_protection.md
- [ ] bugs/history/roadmap/task_warning/task_??_prefer_no_commented_code.md
- [ ] bugs/history/roadmap/task_warning/task_??_prefer_semver_version.md
- [ ] bugs/history/roadmap/task_warning/task_??_prefer_sqflite_encryption.md
- [ ] bugs/history/roadmap/task_warning/task_??_require_auto_route_full_hierarchy.md
- [ ] bugs/history/roadmap/task_warning/task_??_require_conflict_resolution_strategy.md
- [ ] bugs/history/roadmap/task_warning/task_??_require_connectivity_timeout.md
- [ ] bugs/history/roadmap/task_warning/task_??_require_error_handling_graceful.md
- [ ] bugs/history/roadmap/task_warning/task_??_require_exhaustive_sealed_switch.md
- [ ] bugs/history/roadmap/task_warning/task_??_require_firebase_app_check_production.md
- [ ] bugs/history/roadmap/task_warning/task_??_require_init_state_idempotent.md
- [ ] bugs/history/roadmap/task_warning/task_??_require_input_validation.md
- [ ] bugs/history/roadmap/task_warning/task_??_require_late_access_check.md
- [ ] bugs/history/roadmap/task_warning/task_??_require_pagination_for_large_lists.md
- [ ] bugs/history/roadmap/task_warning/task_??_require_ssl_pinning_sensitive.md
- [ ] bugs/history/roadmap/task_warning/task_??_require_text_scale_factor_awareness.md
- [ ] bugs/history/roadmap/task_warning/task_??_require_yield_after_db_write.md
- [ ] bugs/history/roadmap/task_warning/task_??_verify_documented_parameters_exist.md

---

## Phase 2: todos (4 files)

- [ ] bugs/history/todos/todo_001_missing_require_ios_platform_check_rule.md
- [ ] bugs/history/todos/todo_002_missing_avoid_ios_background_fetch_abuse_rule.md
- [ ] bugs/history/todos/todo_003_missing_require_method_channel_error_handling_rule.md
- [ ] bugs/history/todos/todo_004_missing_require_universal_link_validation_rule.md

---

## Phase 2: tooling, user_reports, completed, README (5 files)

- [ ] bugs/history/tooling/publish_audit_failure_flow_fixed.md
- [ ] bugs/history/user_reports/[icealive] fix_regex_parsing_review.md
- [ ] bugs/history/completed/remaining_roadmap_26_rules_implemented.md
- [ ] bugs/history/completed/unit_test_coverage_fixtures_and_instantiation_completed.md
- [ ] bugs/history/README.md

---

**Total: 238 files.** Mark each `[ ]` as `[x]` when reviewed and integrated (or archived/deleted as per plan).

