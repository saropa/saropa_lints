# Remaining Roadmap Rules (Implement All)

**Purpose:** Checklist for implementing all rules from the [task index](README.md).  
**Rule name:** From filename `task_XXX.md` → rule name `XXX`.  
**Implemented:** Rule name (or documented alias) exists in `lib/src/tiers.dart`.

## Status key

| Status          | Meaning                                                    |
| --------------- | ---------------------------------------------------------- |
| **Done**        | Rule is in tiers (implemented).                            |
| **Skip (Hard)** | Cross-file, heuristics, or YAML; defer per PLAN_100_RULES. |
| **To do**       | Not in tiers; single-file AST feasible (Easy or Medium).   |

## Implemented / covered

<!-- cspell:ignore asmap rxdart -->
These task rule names are already implemented (or covered by an existing rule):

- **require_riverpod_lint_package** → covered by **require_riverpod_lint**
- **fold** → covered by **prefer_fold_over_reduce**
- **prefer_const_constructor_declarations** → covered by **prefer_declaring_const_constructor**
- **avoid_freezed_invalid_annotation_target** — implemented (freezed_rules.dart)
- **avoid_referencing_subclasses** — implemented (class_constructor_rules.dart)
- **avoid_test_on_real_device** — implemented (test_rules.dart)
- **avoid_unnecessary_null_aware_elements** — implemented (unnecessary_code_rules.dart)
- **prefer_asmap_over_indexed_iteration** — implemented (collection_rules.dart)
- **prefer_import_over_part** — implemented (structure_rules.dart)
- **prefer_result_type** — implemented (type_rules.dart)
- **prefer_correct_throws** — implemented (documentation_rules.dart)
- **prefer_layout_builder_for_constraints** — implemented (widget_layout_rules.dart)
- **require_const_list_items** — implemented (collection_rules.dart)
- **prefer_context_read_not_watch** → covered by **prefer_context_read_in_callbacks** (provider_rules.dart)
- **prefer_cache_extent** — implemented (scroll_rules.dart)
- **prefer_biometric_protection** — implemented (security_rules.dart)
- **avoid_renaming_representation_getters** — implemented (class_constructor_rules.dart)
- All Easy rules from Batch 1 in PLAN_100_RULES are implemented (see CHANGELOG and tiers).

## Hard (skip for “implement all” single-file batch)

Implement only when cross-file/heuristics/YAML support exists.

| Task                                        | Importance |
| ------------------------------------------- | ---------- |
| task_avoid_importing_entrypoint_exports.md  | High       |
| task_handle_bloc_event_subclasses.md        | High       |
| task_prefer_automatic_dispose.md            | High       |
| task_prefer_composition_over_inheritance.md | High       |
| task_prefer_correct_screenshots.md          | High       |
| task_prefer_inline_comments_sparingly.md    | Medium     |
| task_prefer_intent_filter_export.md         | High       |
| task_require_di_module_separation.md        | High       |
| task_require_resource_tracker.md            | Medium     |

## To do (Easy then Medium; prefer High importance)

Implement in this order: **Easy** first, then **Medium**, and within each group prefer **High** importance.

### Easy – to do

| Rule name                                                    | Importance | Note |
| ------------------------------------------------------------ | ---------- | ---- |
| (All Easy from index are implemented or covered; none left.) |            |      |

### Medium – to do (High importance first)

**Implemented (106 rules):** prefer_auto_route_path_params_simple, prefer_auto_route_typed_args, prefer_bloc_extensions, prefer_branch_io_or_firebase_links, prefer_builder_pattern, prefer_cancellation_token_pattern, prefer_class_destructuring, prefer_closest_context, prefer_compile_time_config, prefer_conditional_logging, prefer_connectivity_debounce, prefer_correct_json_casts, prefer_correct_topics, prefer_dark_mode_colors, prefer_deactivate_for_cleanup, prefer_deep_link_auth, prefer_disk_cache_for_persistence, prefer_find_child_index_callback, prefer_firebase_transaction_for_counters, prefer_flavor_configuration, prefer_flex_for_complex_layout, prefer_freezed_union_types, prefer_geolocation_coarse_location, prefer_getx_builder_over_obx, prefer_go_router_builder, prefer_high_contrast_mode, prefer_hive_compact_periodically, prefer_hive_compact, prefer_hive_web_aware, prefer_injectable_package, prefer_internet_connection_checker, prefer_json_codegen, prefer_late_lazy_initialization, prefer_log_levels, prefer_log_timestamp, prefer_lru_cache, prefer_named_routes_for_deep_links, prefer_notification_custom_sound, prefer_overlay_portal_layout_builder, prefer_permission_minimal_request, prefer_platform_widget_adaptive, prefer_readable_line_length, prefer_riverpod_code_gen, prefer_riverpod_keep_alive, prefer_root_detection, prefer_rxdart_for_complex_streams, prefer_semantics_sort, prefer_sliver_for_mixed_scroll, prefer_stale_while_revalidate, prefer_stream_transformer, prefer_streams_over_polling, prefer_using_for_temp_resources, prefer_webview_sandbox, prefer_whitelist_validation, require_addAutomaticKeepAlives_off, require_api_response_validation, require_api_version_handling, require_auto_route_deep_link_config, require_backup_exclusion, require_cancellable_operations, require_config_validation, require_connectivity_resume_check, require_content_type_validation, require_context_in_build_descendants, require_dispose_verification_tests, require_error_context_in_logs, require_error_message_clarity, require_error_recovery, require_firebase_email_enumeration_protection, require_firebase_composite_index, require_firebase_offline_persistence, require_focus_order, require_getit_dispose_registration, require_heading_hierarchy, require_https_only_test, require_image_memory_cache_limit, require_interface_for_dependency, require_json_date_format_consistency, require_keychain_access, require_performance_test, require_permission_lifecycle_observer, require_provider_update_should_notify, require_reduced_motion_support, require_rtl_support, require_sqflite_index_for_queries, require_stream_cancel_on_error, require_subscription_composite, require_webview_user_agent, require_will_pop_scope, use_closest_build_context, use_specific_deprecation, avoid_screenshot_in_ci, prefer_test_report, avoid_semantics_in_animation, prefer_announce_for_changes, prefer_show_hide, require_link_distinction, require_switch_control, prefer_deferred_imports, prefer_part_over_import, prefer_weak_references, prefer_zone_error_handler, require_multi_factor, prefer_isar_for_complex_queries, prefer_external_keyboard, prefer_outlined_icons.

| Rule name                                     | Importance |
| require_error_handling_graceful               | High       |
| require_exception_documentation               | High       |
| require_example_in_documentation              | High       |
| require_parameter_documentation               | High       |
| require_return_documentation                  | High       |
| suggest_yield_after_db_read                   | High       |
| tag_name                                      | High       |

### Medium – to do (Medium / Low importance)

| Rule name                       | Importance |
| ------------------------------- | ---------- |
| pattern_fields_ordering         | Low        |
| record_fields_ordering          | Low        |

---

## How to implement each rule

1. Open `bugs/roadmap/task_<rule_name>.md` for examples and detection notes.
2. Add rule class in the right `lib/src/rules/*_rules.dart`.
3. Register in `lib/saropa_lints.dart` and add to the correct set in `lib/src/tiers.dart`.
4. Add `testRule(...)` and fixture list entry in `test/*_rules_test.dart`.
5. Add `example_*/lib/.../<rule_name>_fixture.dart` with LINT/OK comments.
6. Add one line under [Unreleased] in `CHANGELOG.md`.
7. Run `dart analyze lib` and the relevant tests.

**Total to do (Medium, excluding Hard):** ~120+ rules. Implement in batches of 10–20; prefer High importance first.
