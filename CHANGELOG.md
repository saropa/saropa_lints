# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Dates are not included in version headers — [pub.dev](https://pub.dev/packages/saropa_lints/changelog) displays publish dates separately.

> **Looking for older changes?** \
> See [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md) for versions 0.1.0 through 5.0.3.

\*\* See the current published changelog: [saropa_lints/changelog](https://pub.dev/packages/saropa_lints/changelog)

---

## [Unreleased]

### Added

- **avoid_cascade_notation** (Stylistic): Discourage use of cascade notation (..) for clarity and maintainability. Reports every cascade expression. Fixture: `example_style/lib/stylistic_control_flow/avoid_cascade_notation_fixture.dart`.
- **prefer_fold_over_reduce** (Stylistic): Prefer fold() with an explicit initial value over reduce() for collections (clarity and empty-collection safety). Fixture: `example_core/lib/collection/prefer_fold_over_reduce_fixture.dart`.
- **avoid_expensive_log_string_construction** (Professional): Flag log() calls whose message argument is a string interpolation; the string is built even when the log level would not print it. Suggests a level guard or lazy message.
- **avoid_returning_this** (Stylistic): Flag methods that return `this`; prefer explicit return types or void.
- **avoid_cubit_usage** (Stylistic): Prefer Bloc over Cubit for event traceability (Bloc package only). Runs only when bloc package is a dependency.
- **prefer_expression_body_getters** (Stylistic): Prefer arrow (=>) for getters with a single return statement.
- **prefer_final_fields_always** (Stylistic): All instance fields should be final. Stricter than `prefer_final_fields` (which only flags when never reassigned).
- **prefer_block_body_setters** (Comprehensive): Prefer block body {} for setters instead of expression body.
- **avoid_riverpod_string_provider_name** (Professional): Detect manual name strings in Riverpod providers; prefer auto-generated name. Documented in `doc/guides/using_with_riverpod.md`. `avoid_cubit_usage` documented in `doc/guides/using_with_bloc.md`.
- **prefer_factory_before_named** (Comprehensive): Place factory constructors before named constructors in class member order.
- **prefer_then_catcherror** (Stylistic): Prefer .then().catchError() over try/catch for async error handling when handling a single Future.
- **avoid_types_on_closure_parameters** (Stylistic): Closure parameters with explicit types; consider removing when the type can be inferred.
- **prefer_fire_and_forget** (Stylistic): Suggest unawaited/fire-and-forget when await result is unused.
- **prefer_for_in_over_foreach** (Stylistic): Prefer for-in over .forEach() on iterables.
- **prefer_foreach_over_map_entries** (Stylistic): Prefer for-in over map.entries instead of Map.forEach.
- **prefer_base_prefix** (Stylistic): Abstract class names should end with Base.
- **prefer_extension_suffix** (Stylistic): Extension names should end with Ext.
- **prefer_mixin_prefix** (Stylistic): Mixin names should end with Mixin.
- **prefer_overrides_last** (Stylistic): Place override methods after non-override members.
- **prefer_i_prefix_interfaces** (Stylistic): Abstract class (interface) names should start with I.
- **prefer_no_i_prefix_interfaces** (Stylistic): Abstract class names should not start with I (opposite of prefer_i_prefix_interfaces).
- **prefer_impl_suffix** (Stylistic): Classes that implement an interface should end with Impl.
- **prefer_constructor_over_literals** (Stylistic): Prefer List.empty(), Map(), Set.empty() over empty list/set/map literals.
- **prefer_constructors_over_static_methods** (Stylistic): Prefer factory constructor when static method only returns new SameClass().
- **format_test_name** (Stylistic): Test names (first argument to test/testWidgets) must be snake_case.
- **avoid_explicit_type_declaration** (Stylistic): Prefer type inference when variable has initializer.
- **prefer_explicit_null_checks** (Stylistic): Prefer explicit == null / != null over !.
- **prefer_non_const_constructors** (Stylistic): Prefer omitting const on constructors (opinionated).
- **prefer_separate_assignments** (Stylistic): Prefer separate statements over cascade assignments (..).
- **prefer_optional_named_params** (Stylistic): Prefer optional named parameters over optional positional.
- **prefer_optional_positional_params** (Stylistic): Prefer optional positional over optional named for bool/flag parameters.
- **prefer_positional_bool_params** (Stylistic): Boolean parameters as optional positional at call sites.
- **prefer_if_else_over_guards** (Stylistic): Consecutive guard clauses could be expressed as if-else.
- **prefer_cascade_assignments** (Stylistic): Consecutive method calls on same target; consider cascade (..).
- **prefer_factory_constructor** (Stylistic): Prefer factory constructor over static method returning same class.
- **require_auto_route_page_suffix** (Stylistic): AutoRoute page classes should have a Page suffix.
- **prefer_inline_function_types** (Stylistic): Prefer inline function type over typedef.
- **prefer_function_over_static_method** (Stylistic): Static method without "this" could be top-level function.
- **prefer_static_method_over_function** (Stylistic): Top-level function with class-typed first param could be static/extension.
- **avoid_unnecessary_null_aware_elements** (Professional): Flag spread elements using `...?` when the collection is non-null; suggest `...` instead.
- **prefer_import_over_part** (Stylistic): Prefer import over part/part of for modularity.
- **prefer_result_type** (Professional): Functions should declare an explicit return type (except main).
- **avoid_freezed_invalid_annotation_target** (Professional): @freezed should only be used on class declarations.
- **require_const_list_items** (Comprehensive): List items that are no-argument constructor calls should be const when possible.
- **prefer_asmap_over_indexed_iteration** (Professional): Prefer asMap().entries for indexed iteration over manual index loops.
- **avoid_test_on_real_device** (Professional): Flag test names that suggest running on real device; prefer emulators/simulators in CI.
- **avoid_referencing_subclasses** (Professional): Base classes should not reference their subclasses (e.g. return/parameter types).
- **prefer_correct_throws** (Professional): Suggest @Throws annotation for methods/functions that throw.
- **prefer_layout_builder_for_constraints** (Professional): Prefer LayoutBuilder for constraint-aware layout instead of MediaQuery for widget sizing.
- **prefer_cache_extent** (Comprehensive): ListView.builder/GridView.builder should specify cacheExtent for predictable scroll performance. Fixture: `example_widgets/lib/scroll/prefer_cache_extent_fixture.dart`.
- **prefer_biometric_protection** (Professional): FlutterSecureStorage should use authenticationRequired in AndroidOptions/IOSOptions. Fixture: `example_async/lib/security/prefer_biometric_protection_fixture.dart`.
- **avoid_renaming_representation_getters** (Professional): Extension type should not expose the representation via a getter with a different name. Fixture: `example_core/lib/class_constructor/avoid_renaming_representation_getters_fixture.dart`.


### Fixed

- **Publish script (audit failure):** When the pre-publish audit fails, the script now auto-fixes only the missing `[rule_name]` prefix in problem messages when applicable, then re-runs the audit. For other blocking issues (tier integrity, duplicates, spelling, .contains() baseline), it exits with a single clear message pointing to the ✗ lines in the audit output instead of offering the DX message improver (which cannot fix those).

- **Report duplicate paths:** The analysis report log counted the same violation twice when the same issue was reported with both relative and absolute file paths (e.g. `lib/foo.dart` and `D:\proj\lib\foo.dart`). Consolidation now normalizes all paths to project-relative form before deduplication and in stored violation records, so totals and "files with issues" are accurate. See `bugs/history/report_duplicate_paths_deduplication.md`.

### Archive

- Rules 5.0.3 and older moved to [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md)

---

## [6.0.10]

### Fixed

- **avoid_deprecated_usage (analyzer 9):** Fixed plugin crash (`NoSuchMethodError: SimpleIdentifierImpl has no getter 'staticElement'`) when running under analyzer 9.x. Rule now uses a compatibility helper that supports both `.element` (analyzer 9+) and `.staticElement` (older). See `bugs/history/report_avoid_deprecated_usage_analyzer_api_crash.md`.
- **Lint message text:** Removed duplicated or malformed text in `correctionMessage` across 11 rule files. No rule logic, tiers, or behavior changed. **code_quality_rules:** `no_boolean_literal_compare` — removed duplicate phrase "!x instead of x == false". **structure_rules:** `prefer_small_length_test_files`, `avoid_medium_length_test_files`, `avoid_long_length_test_files`, `avoid_very_long_length_test_files` — added missing space before "Disable with:". **dependency_injection_rules:** `prefer_constructor_injection` — typo "parameter:." → "parameter.", added space before example. **equatable_rules:** `prefer_equatable_mixin` — fixed "keeping." → "keeping " and sentence order. **widget_lifecycle_rules:** `require_timer_cancellation`, `nullify_after_dispose` — added space before continuation. **ios_rules:** `avoid_ios_deprecated_uikit` — added space before "See Xcode warnings...". **record_pattern_rules:** `avoid_explicit_pattern_field_name` — fixed "instead of." and message order. **widget_layout_rules:** `prefer_spacing_over_sizedbox`, `avoid_deep_widget_nesting`, `prefer_safe_area_aware` — fixed split/space so sentences read correctly. **testing_best_practices_rules:** `avoid_flaky_tests` — fixed "instead of." and sentence order. **test_rules:** `avoid_test_coupling`, `require_test_isolation`, `avoid_real_dependencies_in_tests` — fixed comma/period and continuation order.

---

## [6.0.9]

### Fixed

- **False positive reduction:** Replaced substring/`.contains()` with exact match, word-boundary regex, or type checks. CI baselines updated or removed where violations reached 0. Grouped by rule file; all affected rules listed:
  - **animation_rules:** `require_animation_controller_dispose` — dispose check uses `isFieldCleanedUp()` from `target_matcher_utils` instead of regex on `disposeBody`.
  - **api_network_rules:** `require_http_status_check`, `require_retry_logic`, `require_connectivity_check`, `require_request_timeout`, `prefer_http_connection_reuse`, `avoid_redundant_requests`, `require_response_caching`, `prefer_api_pagination`, `require_offline_indicator`, `prefer_streaming_response`, `avoid_over_fetching`, `require_cancel_token`, `require_websocket_error_handling`, `avoid_websocket_without_heartbeat`, `prefer_timeout_on_requests`, `require_permission_rationale`, `require_permission_status_check`, `require_notification_permission_android13`, `require_sqflite_migration`, `require_websocket_reconnection`, `require_typed_api_response`, `require_image_picker_result_handling`, `require_sse_subscription_cancel` — word-boundary regex or exact sets. Baseline removed (0 violations).
  - **async_rules:** `require_feature_flag_default`, DateTime UTC storage rule, stream listen/StreamController rules, `avoid_dialog_context_after_async`, `require_websocket_message_validation`, `require_loading_timeout`, `prefer_broadcast_stream`, mounted/setState visitors, `require_network_status_check`, `require_pending_changes_indicator`, `avoid_stream_sync_events`, `require_stream_controller_close`, `avoid_stream_subscription_in_field`, `require_stream_subscription_no_leak` — exact target set, `extractTargetName` + `endsWith`, word-boundary regex, or exact `StreamSubscription` type. Baseline removed.
  - **disposal_rules:** `require_media_player_dispose`, `require_tab_controller_dispose`, `require_receive_port_close`, `require_socket_close`, `require_debouncer_cancel`, `require_interval_timer_cancel`, `require_file_handle_close` — `disposeBody.contains(...)` replaced with `isFieldCleanedUp()`. All disposal rules — `typeName.contains(...)` replaced with word-boundary RegExp for media/Tab/WebSocket/VideoPlayer/StreamSubscription/ReceivePort/Socket types. Baseline removed.
  - **file_handling_rules:** PDF rules, sqflite (whereargs, transaction, error handling, batch, close, reserved word, singleton, column constants), large-file rule, `require_file_path_sanitization` — word-boundary regex or static lists. Baseline removed.
  - **navigation_rules:** `avoid_deep_link_sensitive_params`, `prefer_typed_route_params`, `avoid_circular_redirects`, `require_deep_link_fallback`, `require_stepper_validation`, `require_step_count_indicator`, `require_go_router_typed_params`, `require_url_launcher_encoding`, `avoid_navigator_context_issue` — exact property name for queryParameters/pathSegments/pathParameters or word-boundary regex. Baseline removed.
  - **permission_rules:** `require_location_permission_rationale`, `require_camera_permission_check`, `prefer_image_cropping` — word-boundary regex for rationale, camera check, cropper/crop/ImageCropper, profile-context keywords. Baseline removed.
  - **provider_rules:** `avoid_provider_for_single_value` (exact set for Proxy/Multi), `prefer_selector_over_single_watch` (regex for `.select(`), `avoid_provider_value_rebuild` (`endsWith('Provider')`).
  - **security_rules:** RequireSecureStorageRule, RequireBiometricFallbackRule, AvoidStoringPasswordsRule, RequireTokenRefreshRule, AvoidJwtDecodeClientRule, RequireLogoutCleanupRule, RequireDeepLinkValidationRule, AvoidPathTraversalRule, RequireDataEncryptionRule, AvoidLoggingSensitiveDataRule, RequireSecureStorageForAuthRule, AvoidRedirectInjectionRule, PreferLocalAuthRule, RequireSecureStorageAuthDataRule, AvoidStoringSensitiveUnencryptedRule, HTTP client rule, RequireCatchLoggingRule, RequireSecureStorageErrorHandlingRule, AvoidSecureStorageLargeDataRule, RequireClipboardPasteValidationRule, OAuth PKCE rule, session timeout rule, AvoidStackTraceInProductionRule, RequireInputValidationRule — word-boundary RegExp or RegExp.escape. Baseline removed.
  - **widget_lifecycle_rules:** `require_scroll_controller_dispose`, `require_focus_node_dispose` — disposal check uses RegExp for `.dispose()` instead of `disposeBody.contains('.dispose()')`. Baseline 18→16.
  - **False-positive reduction (complete):** All remaining `.contains()` anti-patterns in rule files removed. Tests: `anti_pattern_detection_test` asserts 9 dangerous patterns (sync with publish script); `false_positive_fixes_test` documents word-boundary regression. Discussion 062 archived to `bugs/history/`. Replaced with word-boundary `RegExp`, `isFieldCleanedUp` / `isExactTarget` from `target_matcher_utils`, or exact-set checks in: **accessibility_rules**, **animation_rules**, **bluetooth_hardware_rules**, **collection_rules**, **dependency_injection_rules**, **disposal_rules**, **drift_rules**, **error_handling_rules**, **equatable_rules**, **geolocator_rules**, **get_it_rules**, **getx_rules**, **hive_rules**, **internationalization_rules**, **isar_rules**, **json_datetime_rules**, **memory_management_rules**, **package_specific_rules**, **state_management_rules**, **stylistic_error_testing_rules**, **type_safety_rules**, **ui_ux_rules**, **url_launcher_rules**, **workmanager_rules**. `test/anti_pattern_detection_test.dart` baseline emptied (0 violations); any new dangerous `.contains()` will fail CI.
- **prefer_permission_request_in_context:** Use exact match for Permission target (`Permission` or `Permission.*`) instead of substring match to avoid false positives on unrelated types.

### Changed

- **Roadmap:**
  - Verified all 185 `bugs/roadmap` task files against `lib/src/tiers.dart`; none correspond to implemented rules.
  - Rule quality subsection made self-contained: describes the String.contains() anti-pattern audit (121+ instances across rule files; remediation via exact-match sets or type checks) and `test/anti_pattern_detection_test.dart`; removed references to obsolete review documents.
  - Planned Enhancements table (Discussion #55–#61) removed; details live in `bugs/discussion/` (one file per discussion).
  - Planned rules that have a task file in `bugs/roadmap/` were removed from ROADMAP tables; ROADMAP now points to [bugs/roadmap/](bugs/roadmap/) for task specs.
  - Deferred content merged into ROADMAP.md (Part 2). ROADMAP_DEFERRED.md removed as redundant.
  - Cross-File Analysis CLI roadmap (formerly ROADMAP_CLI.md) merged into ROADMAP.md as **Part 3: Cross-File Analysis CLI Tool Roadmap**. ROADMAP_CLI.md removed.
- **CHANGELOG:** 6.0.7 Added section — consolidated six separate "new lint rules" lists into one list of 55 rules, removed redundant rule-name headers, and ordered entries alphabetically for readability.
- **require_app_startup_error_handling:** Documented that the rule only runs when the project has a crash-reporting dependency (e.g. firebase_crashlytics, sentry_flutter).
- **Tier reclassification (no orphans):** Rule logic, unit tests, and false-positive suppressors unchanged; only tier set membership in `lib/src/tiers.dart` updated. Moved **to Essential:** `check_mounted_after_async`, `avoid_drift_raw_sql_interpolation`. Moved **to Recommended:** `prefer_semver_version`, `prefer_correct_package_name`, `require_macos_notarization_ready`, `avoid_animation_rebuild_waste`, `require_deep_link_fallback`, `require_stepper_validation`, `require_immutable_bloc_state`.
- **Severity reclassification:** `LintCode` severity only; when the rule fires is unchanged. CI using `--fatal-infos` may now fail where it did not. **WARNING → ERROR:** `require_unknown_route_handler`, `avoid_circular_redirects`, `check_mounted_after_async`, `require_https_only`, `require_route_guards`.
- **Discussion 062 (false positive reduction review):** Archived to `bugs/history/discussion_062_false_positive_reduction_review.md` (audit complete 2026-03-01). Ongoing guidance: CONTRIBUTING.md § Avoiding False Positives and `.claude/skills/lint-rules/SKILL.md` § Reducing False Positives.

### Added

- **Publish script (test coverage):** Rule-instantiation status is now derived from the codebase. The Test Coverage report shows a "Rule inst." line (categories with a Rule Instantiation group / categories with a test file) and lists categories missing that group. Implemented in `scripts/modules/_rule_metrics.py` (`_compute_rule_instantiation_stats`); does not read `bugs/UNIT_TEST_COVERAGE_REVIEW.md`.
- **Tests (behavioral):** Added a second test in `test/fixture_lint_integration_test.dart` that runs custom_lint on example_async and asserts specific rule codes (avoid_catch_all, avoid_dialog_context_after_async, require_stream_controller_close, require_feature_flag_default, prefer_specifying_future_value_type) appear in parsed violations when custom_lint runs. When no violations are reported (e.g. resolver conflict), per-rule assertions are skipped. Updated `bugs/UNIT_TEST_COVERAGE_REVIEW.md` §4 (Real behavioral tests — Started).
- **Tests (rule instantiation, full coverage):** Added the Rule Instantiation group to the remaining 45 category test files (bluetooth_hardware, build_method, code_quality, dependency_injection, dialog_snackbar, file_handling, formatting, iap, internationalization, json_datetime, media, money, numeric_literal, permission, record_pattern, resource_management, state_management, stylistic_additional, stylistic_control_flow, stylistic_error_testing, stylistic_null_collection, stylistic, stylistic_whitespace_constructor, stylistic_widget, test, testing_best_practices, unnecessary_code, widget_layout, widget_patterns, plus packages: drift, flame, flutter_hooks, geolocator, graphql, package_specific, qr_scanner, shared_preferences, supabase, url_launcher, workmanager, and platforms: android, ios, linux, macos, windows). All 99 category test files now have Rule Instantiation (one test per rule: code.name, problemMessage, correctionMessage). Updated `bugs/UNIT_TEST_COVERAGE_REVIEW.md` §3.
- **Tests:** `test/fixture_lint_integration_test.dart` — runs `dart run custom_lint` on example_async and asserts output is parseable with `parseViolations`.
- **Missing fixtures (single-per-category):** Added fixtures and test list entries for: freezed (`avoid_freezed_any_map_issue`), notification (`prefer_local_notification_for_immediate`), type_safety (`avoid_redundant_null_check`), ui_ux (`prefer_master_detail_for_large`), widget_lifecycle (`require_init_state_idempotent`).
- **Missing fixtures (two-per-category batch):** Added fixtures and test list entries for: api_network (`prefer_batch_requests`, `require_compression`), code_quality (`avoid_inferrable_type_arguments`), collection (`avoid_function_literals_in_foreach_calls`, `prefer_inlined_adds`), firebase (`avoid_firebase_user_data_in_auth`, `require_firebase_app_check_production`), stylistic_additional (`prefer_sorted_imports`, `prefer_import_group_comments`), web (`avoid_js_rounded_ints`, `prefer_csrf_protection`).
- **Missing fixtures (three-per-category batch):** Added fixtures and test list entries for: control_flow (`avoid_double_and_int_checks`, `prefer_if_elements_to_conditional_expressions`, `prefer_null_aware_method_calls`), hive (`avoid_hive_datetime_local`, `avoid_hive_type_modification`, `avoid_hive_large_single_entry`), performance (`avoid_cache_stampede`, `prefer_binary_format`, `prefer_pool_pattern`), widget_patterns (`avoid_print_in_production`, `avoid_static_route_config`, `require_locale_for_text`).
- **Missing fixtures (naming_style, type, class_constructor):** Added fixtures and test list entries for: naming_style (`prefer_adjective_bool_getters`, `prefer_lowercase_constants`, `prefer_noun_class_names`, `prefer_verb_method_names`), type (`avoid_shadowing_type_parameters`, `avoid_private_typedef_functions`, `prefer_final_locals`, `prefer_const_declarations`), class_constructor (`avoid_accessing_other_classes_private_members`, `avoid_unused_constructor_parameters`, `avoid_field_initializers_in_const_classes`, `prefer_asserts_in_initializer_lists`, `prefer_const_constructors_in_immutables`, `prefer_final_fields`).
- **UNIT_TEST_COVERAGE_REVIEW.md:** Updated §2 table to show 0 missing fixtures for all 27 categories; added completion note and marked recommendation as done.
- **Tests (rule instantiation):** Added Rule Instantiation groups to `animation_rules_test.dart` (19 rules), `collection_rules_test.dart` (25 rules), `control_flow_rules_test.dart` (31 rules), `type_rules_test.dart` (18 rules), `naming_style_rules_test.dart` (28 rules), `class_constructor_rules_test.dart` (20 rules), `structure_rules_test.dart` (45 rules). Each test instantiates the rule and asserts `code.name`, `problemMessage` contains `[code_name]`, `problemMessage.length` > 50, and `correctionMessage` is non-null.
- **Tests (rule instantiation, expanded):** Added the same Rule Instantiation group to 24 additional category test files: `api_network_rules_test.dart` (38), `firebase_rules_test.dart` (28), `performance_rules_test.dart` (46), `ui_ux_rules_test.dart` (19), `widget_lifecycle_rules_test.dart` (36), `type_safety_rules_test.dart` (17), `async_rules_test.dart` (46), `security_rules_test.dart` (55), `navigation_rules_test.dart` (36), `accessibility_rules_test.dart` (39), `provider_rules_test.dart` (26), `riverpod_rules_test.dart` (34), `bloc_rules_test.dart` (46), `getx_rules_test.dart` (23), `architecture_rules_test.dart` (9), `documentation_rules_test.dart` (9), `dio_rules_test.dart` (14), `get_it_rules_test.dart` (3), `image_rules_test.dart` (22), `scroll_rules_test.dart` (17), `equatable_rules_test.dart` (14), `forms_rules_test.dart` (27), and `freezed_rules_test.dart` (10). These tests catch registration and code-name mismatches; behavioral tests (linter-on-code) remain a separate effort. Updated `bugs/UNIT_TEST_COVERAGE_REVIEW.md` §1 and §3 accordingly.
- **Missing fixtures (structure):** Added fixtures and test list entries for: `avoid_classes_with_only_static_members`, `avoid_setters_without_getters`, `prefer_getters_before_setters`, `prefer_static_before_instance`, `prefer_mixin_over_abstract`, `prefer_record_over_tuple_class`, `prefer_sealed_classes`, `prefer_sealed_for_state`, `prefer_constructors_first`, `prefer_extension_methods`, `prefer_extension_over_utility_class`, `prefer_extension_type_for_wrapper`.
- **Tests (rule instantiation + fixtures):** Added rule-instantiation tests (code.name, problemMessage, correctionMessage) and/or missing fixtures for: **Debug:** `prefer_fail_test_case`, `avoid_debug_print`, `avoid_unguarded_debug`, `prefer_commenting_analyzer_ignores`, `prefer_debugPrint`, `avoid_print_in_release`, `require_structured_logging`, `avoid_sensitive_in_logs`, `require_log_level_for_production`. **Complexity:** `avoid_bitwise_operators_with_booleans`, `avoid_cascade_after_if_null`, `avoid_complex_arithmetic_expressions`, `avoid_complex_conditions`, `avoid_duplicate_cascades`, `avoid_excessive_expressions`, `avoid_immediately_invoked_functions`, `avoid_nested_shorthands`, `avoid_multi_assignment`, `binary_expression_operand_order`, `prefer_moving_to_variable`, `prefer_parentheses_with_if_null`, `avoid_deep_nesting`, `avoid_high_cyclomatic_complexity`. **Connectivity:** `require_connectivity_error_handling`, `avoid_connectivity_equals_internet`, `require_connectivity_timeout` (fixture added). **Sqflite:** `avoid_sqflite_type_mismatch`, `prefer_sqflite_encryption` (fixture added). **Config:** `avoid_hardcoded_config`, `avoid_hardcoded_config_test`, `avoid_mixed_environments`, `require_feature_flag_type_safety`, `avoid_string_env_parsing`, `avoid_platform_specific_imports`, `prefer_semver_version`. **Lifecycle:** `avoid_work_in_paused_state`, `require_resume_state_refresh`, `require_did_update_widget_check`, `require_late_initialization_in_init_state`, `require_app_lifecycle_handling`, `require_conflict_resolution_strategy`. **Return:** `avoid_returning_cascades`, `avoid_returning_void`, `avoid_unnecessary_return`, `prefer_immediate_return`, `prefer_returning_shorthands`, `avoid_returning_null_for_void`, `avoid_returning_null_for_future`. **Exception:** `avoid_non_final_exception_class_fields`, `avoid_only_rethrow`, `avoid_throw_in_catch_block`, `avoid_throw_objects_without_tostring`, `prefer_public_exception_classes`. **Equality:** `avoid_equal_expressions`, `avoid_negations_in_equality_checks`, `avoid_self_assignment`, `avoid_self_compare`, `avoid_unnecessary_compare_to`, `no_equal_arguments`, `avoid_datetime_comparison_without_precision`. **Crypto:** `avoid_hardcoded_encryption_keys`, `prefer_secure_random_for_crypto`, `avoid_deprecated_crypto_algorithms`, `require_unique_iv_per_encryption`, `require_secure_key_generation`. **Db_yield:** `require_yield_after_db_write`, `suggest_yield_after_db_read`, `avoid_return_await_db`. **Context:** `avoid_storing_context`, `avoid_context_across_async`, `avoid_context_after_await_in_static`, `avoid_context_in_async_static`, `avoid_context_in_static_methods`, `avoid_context_dependency_in_callback`. **Theming:** `require_dark_mode_testing`, `avoid_elevation_opacity_in_dark`, `prefer_theme_extensions`, `require_semantic_colors`. **Platform:** `require_platform_check`, `prefer_platform_io_conditional`, `prefer_foundation_platform_check`. **Notification:** `require_notification_channel_android`, `avoid_notification_payload_sensitive`, `require_notification_initialize_per_platform`, `require_notification_timezone_awareness`, `avoid_notification_same_id`, `prefer_notification_grouping`, `avoid_notification_silent_failure`, `prefer_local_notification_for_immediate`. **Memory management:** `avoid_large_objects_in_state`, `require_image_disposal`, `avoid_capturing_this_in_callbacks`, `require_cache_eviction_policy`, `prefer_weak_references_for_cache`, `avoid_expando_circular_references`, `avoid_large_isolate_communication`, `require_cache_expiration`, `avoid_unbounded_cache_growth`, `require_cache_key_uniqueness`, `avoid_retaining_disposed_widgets`, `avoid_closure_capture_leaks`, `require_expando_cleanup`. **Disposal:** `require_media_player_dispose`, `require_tab_controller_dispose`, `require_text_editing_controller_dispose`, `require_page_controller_dispose`, `require_lifecycle_observer`, `avoid_websocket_memory_leak`, `require_video_player_controller_dispose`, `require_stream_subscription_cancel`, `require_change_notifier_dispose`, `require_receive_port_close`, `require_socket_close`, `require_debouncer_cancel`, `require_interval_timer_cancel`, `require_file_handle_close`, `require_dispose_implementation`, `prefer_dispose_before_new_instance`, `dispose_class_fields`. **Error handling:** `avoid_swallowing_exceptions`, `avoid_losing_stack_trace`, `avoid_generic_exceptions`, `require_error_context`, `prefer_result_pattern`, `require_async_error_documentation`, `avoid_nested_try_statements`, `require_error_boundary`, `avoid_uncaught_future_errors`, `avoid_print_error`, `require_error_handling_graceful`, `avoid_catch_all`, `avoid_catch_exception_alone`, `avoid_exception_in_constructor`, `require_cache_key_determinism`, `require_permission_permanent_denial_handling`, `require_notification_action_handling`, `require_finally_cleanup`, `require_error_logging`, `require_app_startup_error_handling`, `avoid_assert_in_production`, `handle_throwing_invocations`.

---

## [6.0.7]

### Fixed

- **Unimplemented rule references:** Removed four rules from the plugin registry, tiers, analysis_options_template, and roadmap fixture that were never implemented: `avoid_equals_and_hash_code_on_mutable_classes`, `avoid_implementing_value_types`, `avoid_null_checks_in_equality_operators`, `avoid_redundant_argument_values`. They remain documented in CHANGELOG 6.0.6 Added; can be re-added when implemented.
- **require_yield_after_db_write:** Suppress when write is last statement, when next statement is `return`, when inside `compute()`/`Isolate.run()`, and when file is in test directory. Recognize `Future.microtask`, `Future.delayed(Duration.zero)`, and `SchedulerBinding.instance.endOfFrame` as valid yields. Replace fragile `toString()` check in SchedulerBinding detection with AST-based identifier check.
- **verify_documented_parameters_exist:** Whitelist built-in types and literals (`[String]`, `[int]`, `[null]`, etc.) to avoid false positives on valid doc references.
- **Style:** Satisfy `curly_braces_in_flow_control_structures` in rule implementation files (api_network, control_flow, lifecycle, naming_style, notification, sqflite, performance, web, security, structure, ui_ux, widget_patterns). Single-statement `if` bodies are now wrapped in blocks; no behavior change.

### Changed

- **Firebase reauth rule:** Reauth is now compared by source offset (earliest reauth in method) so order is correct regardless of visit order.
- **Firebase token rule:** Stored detection now includes VariableDeclaration initializer (e.g. `final t = await user.getIdToken()`).
- **Performance:** Firebase Auth rules set requiredPatterns for earlier file skip when content does not match.
- **no_empty_block:** Confirmed existing implementation in `unnecessary_code_rules.dart`; roadmap task archived.
- **GitHub:**
  - Closed issues [#13](https://github.com/saropa/saropa_lints/issues/13) (prefer_pool_pattern), [#14](https://github.com/saropa/saropa_lints/issues/14) (require_expando_cleanup), [#15](https://github.com/saropa/saropa_lints/issues/15) (require_compression), [#16](https://github.com/saropa/saropa_lints/issues/16) (prefer_batch_requests), [#18](https://github.com/saropa/saropa_lints/issues/18) (prefer_binary_format). Each was commented with resolution version v6.0.7 and closed as completed.
  - Closed issues [#20](https://github.com/saropa/saropa_lints/issues/20), [#29](https://github.com/saropa/saropa_lints/issues/29) (require_pagination_for_large_lists, v6.0.7), [#25](https://github.com/saropa/saropa_lints/issues/25), [#34](https://github.com/saropa/saropa_lints/issues/34) (require_rtl_layout_support, v4.15.1), [#24](https://github.com/saropa/saropa_lints/issues/24), [#33](https://github.com/saropa/saropa_lints/issues/33) (prefer_sliverfillremaining_for_empty, v4.14.5), [#26](https://github.com/saropa/saropa_lints/issues/26), [#35](https://github.com/saropa/saropa_lints/issues/35) (require_stepper_state_management, v4.14.5), [#38](https://github.com/saropa/saropa_lints/issues/38) (avoid_infinite_scroll_duplicate_requests, v4.14.5). Each was commented with the resolution version and closed as completed.

### Added

- 55 new lint rules:
  - `avoid_deprecated_usage` (Recommended, WARNING) — use of deprecated APIs from other packages; same-package and generated files ignored.
  - `avoid_unnecessary_containers` (Recommended, INFO) — Container with only child (and optionally key); remove and use child directly (widget files only).
  - `banned_usage` (Professional, WARNING) — Configurable ban list for identifiers (e.g. `print`). No-op without config in `analysis_options_custom.yaml`. Whole-word match; optional `allowedFiles` per entry.
  - `handle_throwing_invocations` (Professional, INFO) — invocations that can throw (e.g. @Throws, readAsStringSync, jsonDecode) not in try/catch.
  - `prefer_adjacent_strings` (Recommended, INFO) — use adjacent string literals instead of `+` for literal concatenation.
  - `prefer_adjective_bool_getters` (Professional, INFO) — bool getters should use predicate names (is/has/can) not verb names (validate/load).
  - `prefer_asserts_in_initializer_lists` (Professional, INFO) — move leading assert() from constructor body to initializer list.
  - `prefer_batch_requests` (Professional, INFO) — await in for-loop with fetch-like method names; suggest batch endpoints. Resolves [#16](https://github.com/saropa/saropa_lints/issues/16).
  - `prefer_binary_format` (Comprehensive, INFO) — jsonDecode in hot path (timer/stream); suggest protobuf/MessagePack or compute(). Resolves [#18](https://github.com/saropa/saropa_lints/issues/18).
  - `prefer_const_constructors_in_immutables` (Professional, INFO) — @immutable or StatelessWidget/StatefulWidget subclasses with only final fields should have a const constructor.
  - `prefer_const_declarations` (Recommended, INFO) — final variables with constant initializers could be const (locals, static, top-level).
  - `prefer_const_literals_to_create_immutables` (Recommended, INFO) — non-const collection literals passed to immutable widget constructors (widget files only).
  - `prefer_constructors_first` (Professional, INFO) — constructors should appear before methods in a class.
  - `prefer_csrf_protection` (Professional, WARNING) — State-changing HTTP with Cookie header must include CSRF token or Bearer auth. Web/WebView projects only. OWASP M3/A07.
  - `prefer_extension_methods` (Professional, INFO) — top-level functions that could be extension methods on first parameter type.
  - `prefer_extension_over_utility_class` (Professional, INFO) — class with only static methods sharing first param type could be an extension.
  - `prefer_extension_type_for_wrapper` (Professional, INFO) — single-field wrapper class could be an extension type (Dart 3.3+).
  - `prefer_final_fields` (Professional, INFO) — fields never reassigned (except via setter) could be final.
  - `prefer_final_locals` (Recommended, INFO) — local variables never reassigned should be final.
  - `prefer_form_bloc_for_complex` (Professional, INFO) — Form with >5 fields suggests form state management (FormBloc, reactive_forms, etc.).
  - `prefer_getters_before_setters` (Professional, INFO) — setter should appear after its getter.
  - `prefer_if_elements_to_conditional_expressions` (Recommended, INFO) — use if element instead of ternary with null in collections.
  - `prefer_inlined_adds` (Recommended, INFO) — prefer inline list/set literal over empty then add/addAll.
  - `prefer_interpolation_to_compose` (Recommended, INFO) — prefer string interpolation over + with literals.
  - `prefer_local_notification_for_immediate` (Recommended, INFO) — FCM for server-triggered messages; use flutter_local_notifications for app-generated.
  - `prefer_lowercase_constants` (Recommended, INFO) — const/static final should use lowerCamelCase.
  - `prefer_master_detail_for_large` (Professional, INFO) — list navigation without MediaQuery/LayoutBuilder; suggest master-detail on tablets.
  - `prefer_mixin_over_abstract` (Professional, INFO) — abstract class with no abstract members and no generative constructor → mixin.
  - `prefer_named_bool_params` (Professional, INFO) — prefer named bool parameters in small functions.
  - `prefer_no_commented_code` — Alias for existing `prefer_no_commented_out_code` (stylistic).
  - `prefer_noun_class_names` (Professional, INFO) — concrete classes should use noun/agent names, not gerund/-able.
  - `prefer_null_aware_method_calls` (Recommended, INFO) — use ?. instead of if (x != null) { x.foo(); }.
  - `prefer_pool_pattern` (Comprehensive, INFO) — non-const allocation in hot path (timer/animation); suggest object pool. Resolves [#13](https://github.com/saropa/saropa_lints/issues/13).
  - `prefer_raw_strings` (Professional, INFO) — use raw string when only escaped backslashes (e.g. regex).
  - `prefer_record_over_tuple_class` (Professional, INFO) — simple data class with only final fields → record.
  - `prefer_sealed_classes` (Professional, INFO) — abstract class with 2+ concrete subclasses in same file → sealed.
  - `prefer_sealed_for_state` (Professional, INFO) — state/event/result abstract with local subclasses → sealed.
  - `prefer_semver_version` (Essential, WARNING) — pubspec.yaml `version` must be major.minor.patch (e.g. 1.0.0, 2.3.1+4). Reports when invalid.
  - `prefer_sqflite_encryption` (Professional, WARNING) — Sensitive DB paths (user/auth/health/payment etc.) with sqflite should use sqflite_sqlcipher. OWASP M9.
  - `prefer_static_before_instance` (Professional, INFO) — static members before instance in same category.
  - `prefer_verb_method_names` (Professional, INFO) — methods should use verb names, not noun-only.
  - `require_compression` (Comprehensive, INFO) — HTTP get/post/put/delete without Accept-Encoding; suggest gzip. Resolves [#15](https://github.com/saropa/saropa_lints/issues/15).
  - `require_conflict_resolution_strategy` (Professional, WARNING) — Sync/upload/push methods that overwrite data should compare timestamps or show conflict UI.
  - `require_connectivity_timeout` (Essential, WARNING) — HTTP/client/dio requests must have a timeout (e.g. `.timeout(Duration(seconds: 30))`).
  - `require_error_handling_graceful` — flag raw exception (e.toString(), e.message, $e) shown in Text/SnackBar/AlertDialog inside catch blocks; recommend friendly messages.
  - `require_exhaustive_sealed_switch` — switch on sealed types must use explicit cases; avoid default/wildcard (same logic as avoid_wildcard_cases_with_sealed_classes, Essential-tier name).
  - `require_expando_cleanup` (Comprehensive, INFO) — Expando with entries added but no cleanup (expando[key] = null). Resolves [#14](https://github.com/saropa/saropa_lints/issues/14).
  - `require_firebase_reauthentication` — sensitive Firebase Auth ops (delete, updateEmail, updatePassword) must be preceded by reauthenticateWithCredential/reauthenticateWithProvider in the same method (firebase_auth only).
  - `require_firebase_token_refresh` — getIdToken() result stored (variable/prefs) without idTokenChanges listener or forceRefresh (firebase_auth only).
  - `require_init_state_idempotent` (Essential, WARNING) — addListener/addObserver in initState must have matching removeListener/removeObserver in dispose (Flutter widget files).
  - `require_input_validation` (Essential, WARNING) — Raw controller `.text` in post/put/patch body without trim/validate/isEmpty. OWASP M1/M4.
  - `require_late_access_check` (Professional, WARNING) — late non-final field set in a method other than constructor/initState and read in another method without initialization check; risk of LateInitializationError.
  - `require_pagination_for_large_lists` (Essential, WARNING) — ListView.builder/GridView.builder with itemCount from bulk-style list (e.g. allProducts.length) without pagination; OOM and jank risk. Suppressed when project uses infinite_scroll_pagination. Resolves [#20](https://github.com/saropa/saropa_lints/issues/20), [#29](https://github.com/saropa/saropa_lints/issues/29).
  - `require_ssl_pinning_sensitive` (Professional, WARNING) — HTTP POST/PUT/PATCH to sensitive paths (/auth, /login, /token) without certificate pinning; OWASP M5, M3. Suppressed when project uses http_certificate_pinning or ssl_pinning_plugin, and for localhost.
  - `require_text_scale_factor_awareness` — Container/SizedBox with literal height containing Text may overflow at large text scale; recommend flexible layout (widget files only).

---

## [6.0.6]

### Added

- 15 new lint rules:
  - `avoid_bool_in_widget_constructors` (Professional, INFO) — widget constructors with named bool params; prefer enum or decomposition
  - `avoid_classes_with_only_static_members` (Recommended, INFO) — prefer top-level functions/constants
  - `avoid_double_and_int_checks` (Professional, INFO) — flag `is int && is double` (always false) and `is int || is double` (use `is num`)
  - `avoid_equals_and_hash_code_on_mutable_classes` (Professional, INFO) — custom ==/hashCode with mutable fields breaks Set/Map
  - `avoid_escaping_inner_quotes` (Stylistic, INFO) — switch quote delimiter to avoid escaped inner quotes
  - `avoid_field_initializers_in_const_classes` (Professional, INFO) — move field initializers to const constructor initializer list
  - `avoid_function_literals_in_foreach_calls` (Stylistic, INFO) — prefer for-in over .forEach with a literal
  - `avoid_implementing_value_types` (Professional, INFO) — implements type with custom ==/hashCode without overriding them
  - `avoid_js_rounded_ints` (Comprehensive, INFO) — integer literals exceeding JS safe integer range (2^53)
  - `avoid_null_checks_in_equality_operators` (Professional, INFO) — redundant other == null when is! type test present
  - `avoid_positional_boolean_parameters` (Professional, INFO) — use named parameters for bools
  - `avoid_private_typedef_functions` (Comprehensive, INFO) — private typedef for function type; prefer inline type
  - `avoid_redundant_argument_values` (Recommended, INFO) — named argument equals parameter default
  - `avoid_setters_without_getters` (Professional, INFO) — setter with no matching getter
  - `avoid_single_cascade_in_expression_statements` (Stylistic, INFO) — single cascade as statement; use direct call

### Changed

- **Init wizard (stylistic walkthrough):** Boolean naming rules are in their own category so "[a] enable all in category" applies to all four; progress shows global position (e.g. 51/143) on resume instead of resetting to 1/N; GOOD/BAD labels are bold and colored; the four boolean rules now have distinct good/bad examples (fields, params, locals, and all booleans) so the wizard differentiates them clearly.

### Fixed

- `require_minimum_contrast` — ignore comments were not honored; rule now respects `// ignore: require_minimum_contrast` and `// ignore_for_file: require_minimum_contrast` (and hyphenated forms) via `IgnoreUtils`

---

## [6.0.5]

### Fixed

- `avoid_path_traversal` — false positive when trusted platform path (e.g., `getApplicationDocumentsDirectory`) is passed to a private helper method; now traces trust through call sites of private methods
- `require_file_path_sanitization` — same false positive as `avoid_path_traversal`; shared inter-procedural platform path trust check

## [6.0.4]

### Fixed

- `avoid_dynamic_sql` — false positive on SQLite PRAGMA statements which do not support parameter binding; now exempts PRAGMA syntax. Also improved SQL keyword matching to use word boundaries (prevents false positives from identifiers like `selection`, `updateTime`)
- `avoid_ref_read_inside_build` — false positive on `ref.read()` inside callbacks (onPressed, onSubmit, etc.) defined inline in `build()`; now stops traversal at closure boundaries
- `avoid_ref_in_build_body` — same false positive as above; now shares the corrected visitor with `avoid_ref_read_inside_build`
- `avoid_ref_watch_outside_build` — false positive on `ref.watch()` inside Riverpod provider bodies (`Provider`, `StreamProvider`, `FutureProvider`, etc.); now recognizes provider callbacks as reactive contexts alongside `build()`
- `avoid_path_traversal` — false positive when file path parameter originates from platform path APIs (`getApplicationDocumentsDirectory`, `getTemporaryDirectory`, etc.); now recognizes these as trusted sources
- `require_file_path_sanitization` — same false positive as `avoid_path_traversal`; now recognizes platform path APIs as trusted
- `avoid_unsafe_collection_methods` — false positive on `.first`/`.last` when guarded by early-return (`if (list.isEmpty) return;`) or when the collection is a callback parameter guaranteed non-empty (e.g., `SegmentedButton.onSelectionChanged`)
- `avoid_unsafe_reduce` — false positive on `reduce()` guarded by `if (list.length < N) return;` or `if (list.isEmpty) return;`; now detects early-return and if/ternary guards
- `require_app_startup_error_handling` — false positive on apps without a crash reporting dependency; now only fires when a monitoring package (e.g., `firebase_crashlytics`, `sentry_flutter`) is detected in pubspec.yaml
- `require_search_debounce` — false positive when Timer-based debounce is defined as a class field rather than inline in the callback; now checks enclosing class for Timer/Debouncer field declarations
- `require_minimum_contrast` — false positive when text color is light but background is set via a variable that can't be resolved statically; now recognizes containers with unresolvable background colors as intentionally set

---

## [6.0.3]

### Fixed

- `avoid_drift_close_streams_in_tests` — rule never fired because `testRelevance` was not overridden; the framework skipped test files before the rule could run. Now correctly set to `TestRelevance.testOnly`
- `avoid_drift_update_without_where` — removed unreachable dead code branch

---

## [6.0.2]

### Changed

- Widened `analysis_server_plugin` and `analyzer_plugin` dependency constraints from pinned to `^` range to reduce version conflicts for consumers

### Fixed

- CI publish workflow: dry run step failed on exit code 65 (warnings) due to `set -e` killing the shell before the exit code could be evaluated; warnings are now reported via GitHub Actions annotations without blocking the publish

---

## [6.0.1]

### Added

- 10 additional Drift lint rules covering common gotchas, Value semantics, migration safety, and Isar-to-Drift migration patterns (total: 31 Drift rules)
  - `avoid_drift_value_null_vs_absent` (Recommended, WARNING) — detects `Value(null)` instead of `Value.absent()`
  - `require_drift_equals_value` (Recommended, WARNING) — detects `.equals()` with enum/converter columns instead of `.equalsValue()`
  - `require_drift_read_table_or_null` (Recommended, WARNING) — detects `readTable()` with leftOuterJoin instead of `readTableOrNull()`
  - `require_drift_create_all_in_oncreate` (Recommended, WARNING) — detects `onCreate` callback missing `createAll()`
  - `avoid_drift_validate_schema_production` (Professional, WARNING) — detects `validateDatabaseSchema()` without debug guard
  - `avoid_drift_replace_without_all_columns` (Professional, INFO) — detects `.replace()` on update builder instead of `.write()`
  - `avoid_drift_missing_updates_param` (Professional, INFO) — detects `customUpdate`/`customInsert` without `updates` parameter
  - `avoid_isar_import_with_drift` (Recommended, WARNING) — detects files importing both Isar and Drift packages
  - `prefer_drift_foreign_key_declaration` (Professional, INFO) — detects `Id`-suffixed columns without `references()`
  - `require_drift_onupgrade_handler` (Recommended, WARNING) — detects schemaVersion > 1 without `onUpgrade` handler

### Fixed

- `avoid_drift_missing_updates_param` — missing drift import check caused false positives on non-drift `customUpdate()` calls
- `prefer_drift_foreign_key_declaration` — false positives on non-FK column names (`androidId`, `deviceId`, `sessionId`, etc.)
- `require_drift_equals_value` — false positives on non-enum uppercase types (`DateTime`, `Duration`, `BigInt`, etc.)
- `require_drift_onupgrade_handler` — reduced performance cost by checking individual members instead of full class `toSource()`

---

## [6.0.0]

### Breaking

- Upgraded `analyzer` from ^8.0.0 to ^9.0.0
- Pinned `analysis_server_plugin` to 0.3.4 (only version targeting analyzer v9)
- Pinned `analyzer_plugin` to 0.13.11 (only version targeting analyzer v9)
- Requires Dart SDK >=3.10.0

### Added

- 21 new Drift (SQLite) database lint rules covering data safety, resource management, SQL injection prevention, migration correctness, performance, and web platform safety
  - `avoid_drift_enum_index_reorder` (Essential, ERROR)
  - `require_drift_database_close` (Recommended, WARNING)
  - `avoid_drift_update_without_where` (Recommended, WARNING)
  - `require_await_in_drift_transaction` (Recommended, WARNING)
  - `require_drift_foreign_key_pragma` (Recommended, WARNING)
  - `avoid_drift_raw_sql_interpolation` (Recommended, ERROR)
  - `prefer_drift_batch_operations` (Recommended, WARNING)
  - `require_drift_stream_cancel` (Recommended, WARNING)
  - `avoid_drift_database_on_main_isolate` (Professional, INFO)
  - `avoid_drift_log_statements_production` (Professional, WARNING)
  - `avoid_drift_get_single_without_unique` (Professional, INFO)
  - `prefer_drift_use_columns_false` (Professional, INFO)
  - `avoid_drift_lazy_database` (Professional, INFO)
  - `prefer_drift_isolate_sharing` (Professional, INFO)
  - `avoid_drift_query_in_migration` (Comprehensive, WARNING)
  - `require_drift_schema_version_bump` (Comprehensive, INFO)
  - `avoid_drift_foreign_key_in_migration` (Comprehensive, INFO)
  - `require_drift_reads_from` (Comprehensive, INFO)
  - `avoid_drift_unsafe_web_storage` (Comprehensive, INFO)
  - `avoid_drift_close_streams_in_tests` (Comprehensive, INFO)
  - `avoid_drift_nullable_converter_mismatch` (Comprehensive, INFO)
- Drift added as supported package in package filtering system

### Changed

- Migrated all `NamedType.name2` references to `NamedType.name` (analyzer v9 API)
- Migrated `VariableDeclaration.declaredElement` to `declaredFragment.element` (analyzer v9 API)
- Removed deprecated `errorCode` parameter from `SaropaDiagnosticReporter.atOffset()`

---

## [5.0.3] and Earlier

For details on the initial release and versions 0.1.0 through 5.0.3, please refer to [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md).
