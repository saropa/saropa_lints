# Roadmap task reports

This folder contains one detailed task report per planned rule from [ROADMAP.md](../../ROADMAP.md). Each report covers examples, detection vs. false positives, external references, and quality/performance notes.

**Placeholders**: Task files no longer use "TODO: Replace with concrete example"; they include a **Detection approach** line and instruct implementers to add concrete bad/good examples (or mark "Needs design") before implementing. Rules that require pubspec/YAML or cross-file analysis are listed in ROADMAP.md Part 2 (Deferred) and do not have task files here.

**Implemented check:** Task filenames are checked against `lib/src/tiers.dart`. During **publish** (Step 1), any task file whose rule is already in tiers is removed automatically. No need to run a separate script; the logic lives in `scripts/modules/_roadmap_implemented.py`.

## Legend

**Ease of implementation**

| Value | Meaning |
|-------|--------|
| Easy | Single-file AST; simple pattern (e.g. naming, ordering, pubspec); no cross-file or package detection |
| Medium | Single-file with type/element checks; or package-scoped (e.g. `ProjectContext.usesPackage`) |
| Hard | Cross-file analysis, heuristics, YAML/config parsing, or many edge cases |

**Importance**

| Value | Meaning |
|-------|--------|
| High | Recommended or Professional tier; prevents bugs, security, or major UX issues |
| Medium | Comprehensive tier; improves correctness or best practices |
| Low | Pedantic or Stylistic; preference or polish |

## Task index

| Filename | Ease of implementation | Importance |
|----------|------------------------|------------|
| task_avoid_explicit_type_declaration.md | Easy | Low |
| task_avoid_freezed_invalid_annotation_target.md | Medium | High |
| task_avoid_hardcoded_config_test.md | Medium | High |
| task_avoid_importing_entrypoint_exports.md | Hard | High |
| task_avoid_misleading_documentation.md | Medium | High |
| task_avoid_referencing_subclasses.md | Medium | High |
| task_avoid_renaming_representation_getters.md | Medium | High |
| task_avoid_screenshot_in_ci.md | Medium | Medium |
| task_avoid_semantics_in_animation.md | Medium | Medium |
| task_avoid_test_on_real_device.md | Medium | High |
| task_avoid_types_on_closure_parameters.md | Easy | Low |
| task_avoid_unnecessary_null_aware_elements.md | Medium | High |
| task_fold.md | Easy | Low |
| task_format_test_name.md | Easy | Low |
| task_handle_bloc_event_subclasses.md | Hard | High |
| task_pattern_fields_ordering.md | Medium | Low |
| task_prefer_announce_for_changes.md | Medium | Medium |
| task_prefer_asmap_over_indexed_iteration.md | Medium | High |
| task_prefer_auto_route_path_params_simple.md | Medium | High |
| task_prefer_auto_route_typed_args.md | Medium | High |
| task_prefer_automatic_dispose.md | Hard | High |
| task_prefer_base_prefix.md | Easy | Medium |
| task_prefer_biometric_protection.md | Medium | High |
| task_prefer_bloc_extensions.md | Medium | High |
| task_prefer_branch_io_or_firebase_links.md | Medium | High |
| task_prefer_builder_pattern.md | Medium | High |
| task_prefer_cache_extent.md | Medium | High |
| task_prefer_cancellation_token_pattern.md | Medium | High |
| task_prefer_cascade_assignments.md | Easy | Low |
| task_prefer_class_destructuring.md | Medium | High |
| task_prefer_closest_context.md | Medium | High |
| task_prefer_compile_time_config.md | Medium | High |
| task_prefer_composition_over_inheritance.md | Hard | High |
| task_prefer_conditional_logging.md | Medium | High |
| task_prefer_connectivity_debounce.md | Medium | High |
| task_prefer_const_constructor_declarations.md | Easy | Low |
| task_prefer_constructor_over_literals.md | Easy | Low |
| task_prefer_constructors_over_static_methods.md | Easy | Low |
| task_prefer_context_read_not_watch.md | Medium | High |
| task_prefer_correct_json_casts.md | Medium | High |
| task_prefer_correct_screenshots.md | Hard | High |
| task_prefer_correct_throws.md | Medium | High |
| task_prefer_correct_topics.md | Medium | High |
| task_prefer_dark_mode_colors.md | Medium | High |
| task_prefer_deactivate_for_cleanup.md | Medium | High |
| task_prefer_deep_link_auth.md | Medium | High |
| task_prefer_deferred_imports.md | Medium | Medium |
| task_prefer_disk_cache_for_persistence.md | Medium | High |
| task_prefer_explicit_null_checks.md | Easy | Low |
| task_prefer_extension_suffix.md | Easy | Medium |
| task_prefer_external_keyboard.md | Medium | Medium |
| task_prefer_factory_before_named.md | Easy | Medium |
| task_prefer_factory_constructor.md | Easy | Low |
| task_prefer_find_child_index_callback.md | Medium | High |
| task_prefer_fire_and_forget.md | Easy | Low |
| task_prefer_firebase_transaction_for_counters.md | Medium | High |
| task_prefer_flavor_configuration.md | Medium | High |
| task_prefer_flex_for_complex_layout.md | Medium | High |
| task_prefer_foreach_over_map_entries.md | Easy | Low |
| task_prefer_foreach.md | Easy | Low |
| task_prefer_freezed_union_types.md | Medium | High |
| task_prefer_function_over_static_method.md | Easy | Medium |
| task_prefer_geolocator_coarse_location.md | Medium | High |
| task_prefer_getx_builder_over_obx.md | Medium | High |
| task_prefer_go_router_builder.md | Medium | High |
| task_prefer_high_contrast_mode.md | Medium | High |
| task_prefer_hive_compact_periodically.md | Medium | High |
| task_prefer_hive_compact.md | Medium | High |
| task_prefer_hive_web_aware.md | Medium | High |
| task_prefer_i_prefix_interfaces.md | Easy | Medium |
| task_prefer_if_else_over_guards.md | Easy | Low |
| task_prefer_impl_suffix.md | Easy | Medium |
| task_prefer_import_group_comments.md | Easy | Low |
| task_prefer_import_over_part.md | Medium | High |
| task_prefer_injectable_package.md | Medium | High |
| task_prefer_inline_comments_sparingly.md | Hard | Medium |
| task_prefer_inline_function_types.md | Easy | Medium |
| task_prefer_intent_filter_export.md | Hard | High |
| task_prefer_internet_connection_checker.md | Medium | High |
| task_prefer_isar_for_complex_queries.md | Medium | Medium |
| task_prefer_js_interop_over_dart_js.md | Medium | High |
| task_prefer_json_codegen.md | Medium | High |
| task_prefer_late_lazy_initialization.md | Medium | High |
| task_prefer_layout_builder_for_constraints.md | Medium | High |
| task_prefer_log_levels.md | Medium | High |
| task_prefer_log_timestamp.md | Medium | High |
| task_prefer_lru_cache.md | Medium | High |
| task_prefer_mixin_prefix.md | Easy | Medium |
| task_prefer_named_routes_for_deep_links.md | Medium | High |
| task_prefer_no_i_prefix_interfaces.md | Easy | Medium |
| task_prefer_non_const_constructors.md | Easy | Low |
| task_prefer_notification_custom_sound.md | Medium | High |
| task_prefer_optional_named_params.md | Easy | High |
| task_prefer_optional_positional_params.md | Easy | Medium |
| task_prefer_outlined_icons.md | Medium | Medium |
| task_prefer_overlay_portal_layout_builder.md | Medium | High |
| task_prefer_overrides_last.md | Easy | Medium |
| task_prefer_part_over_import.md | Medium | Low |
| task_prefer_permission_minimal_request.md | Medium | High |
| task_prefer_platform_widget_adaptive.md | Medium | High |
| task_prefer_positional_bool_params.md | Easy | Medium |
| task_prefer_readable_line_length.md | Medium | High |
| task_prefer_result_type.md | Medium | High |
| task_prefer_riverpod_code_gen.md | Medium | High |
| task_prefer_riverpod_keep_alive.md | Medium | High |
| task_prefer_root_detection.md | Medium | High |
| task_prefer_rxdart_for_complex_streams.md | Medium | High |
| task_prefer_semantics_sort.md | Medium | High |
| task_prefer_separate_assignments.md | Easy | Low |
| task_prefer_show_hide.md | Medium | Medium |
| task_prefer_sliver_for_mixed_scroll.md | Medium | High |
| task_prefer_sorted_imports.md | Easy | Medium |
| task_prefer_stale_while_revalidate.md | Medium | High |
| task_prefer_static_method_over_function.md | Easy | Medium |
| task_prefer_stream_transformer.md | Medium | High |
| task_prefer_streams_over_polling.md | Medium | High |
| task_prefer_test_report.md | Medium | Medium |
| task_prefer_then_catcherror.md | Easy | Low |
| task_prefer_using_for_temp_resources.md | Medium | High |
| task_prefer_weak_references.md | Medium | Medium |
| task_prefer_webview_sandbox.md | Medium | High |
| task_prefer_whitelist_validation.md | Medium | High |
| task_prefer_zone_error_handler.md | Medium | Medium |
| task_record_fields_ordering.md | Medium | Low |
| task_require_addAutomaticKeepAlives_off.md | Medium | High |
| task_require_api_response_validation.md | Medium | High |
| task_require_api_version_handling.md | Medium | High |
| task_require_auto_route_deep_link_config.md | Medium | High |
| task_require_auto_route_page_suffix.md | Easy | Low |
| task_require_backup_exclusion.md | Medium | High |
| task_require_cancellable_operations.md | Medium | High |
| task_require_config_validation.md | Medium | High |
| task_require_complex_logic_comments.md | Medium | High |
| task_require_connectivity_resume_check.md | Medium | High |
| task_require_const_list_items.md | Medium | High |
| task_require_content_type_validation.md | Medium | High |
| task_require_context_in_build_descendants.md | Medium | High |
| task_require_di_module_separation.md | Hard | High |
| task_require_dispose_verification_tests.md | Medium | High |
| task_require_error_context_in_logs.md | Medium | High |
| task_require_error_handling_graceful.md | Medium | High |
| task_require_error_message_clarity.md | Medium | High |
| task_require_error_recovery.md | Medium | High |
| task_require_exception_documentation.md | Medium | High |
| task_require_example_in_documentation.md | Medium | High |
| task_require_firebase_email_enumeration_protection.md | Medium | High |
| task_require_firebase_composite_index.md | Medium | High |
| task_require_firebase_offline_persistence.md | Medium | High |
| task_require_focus_order.md | Medium | High |
| task_require_getit_dispose_registration.md | Medium | High |
| task_require_heading_hierarchy.md | Medium | High |
| task_require_https_only_test.md | Medium | High |
| task_require_image_memory_cache_limit.md | Medium | High |
| task_require_interface_for_dependency.md | Medium | High |
| task_require_json_date_format_consistency.md | Medium | High |
| task_require_keychain_access.md | Medium | High |
| task_require_link_distinction.md | Medium | Medium |
| task_require_multi_factor.md | Medium | Medium |
| task_require_performance_test.md | Medium | High |
| task_require_parameter_documentation.md | Medium | High |
| task_require_permission_lifecycle_observer.md | Medium | High |
| task_require_provider_update_should_notify.md | Medium | High |
| task_require_reduced_motion_support.md | Medium | High |
| task_require_resource_tracker.md | Hard | Medium |
| task_require_return_documentation.md | Medium | High |
| task_require_riverpod_lint_package.md | Easy | High |
| task_require_rtl_support.md | Medium | High |
| task_require_sqflite_index_for_queries.md | Medium | High |
| task_require_stream_cancel_on_error.md | Medium | High |
| task_require_subscription_composite.md | Medium | High |
| task_require_switch_control.md | Medium | Medium |
| task_require_webview_user_agent.md | Medium | High |
| task_require_will_pop_scope.md | Medium | High |
| task_suggest_yield_after_db_read.md | Medium | High |
| task_tag_name.md | Medium | High |
| task_use_closest_build_context.md | Medium | High |
| task_use_specific_deprecation.md | Medium | High |

---

Update **Ease** and **Importance** as you implement or triage; prefer High-importance and Easy/Medium-ease tasks first.
