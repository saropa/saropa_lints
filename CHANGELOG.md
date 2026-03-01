# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Dates are not included in version headers — [pub.dev](https://pub.dev/packages/saropa_lints/changelog) displays publish dates separately.

> **Looking for older changes?** \
> See [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md) for versions 0.1.0 through 4.15.1.

\*\* See the current published changelog: [saropa_lints/changelog](https://pub.dev/packages/saropa_lints/changelog)

---

## [Unreleased]

### Fixed

- **False positive reduction (disposal_rules):** Replaced `disposeBody.contains(...)` with `isFieldCleanedUp()` from `target_matcher_utils` so disposal detection is robust to formatting and null-aware calls. Rules updated: `require_media_player_dispose`, `require_tab_controller_dispose`, `require_receive_port_close`, `require_socket_close`, `require_debouncer_cancel`, `require_interval_timer_cancel`, `require_file_handle_close`. CI baseline for `disposal_rules.dart` reduced (anti_pattern_detection_test).
- **False positive reduction (Phase 2):** Replaced substring checks with exact or word-boundary checks. **navigation_rules:** `avoid_deep_link_sensitive_params`, `prefer_typed_route_params` — use exact property name (`_indexTargetPropertyOrName`) for `queryParameters`/`pathSegments`/`pathParameters` instead of `targetSource.contains(...)`. **api_network_rules:** `require_http_status_check` — use word-boundary regex for `http.get`/`dio.get`/`statusCode`/`isSuccessful` to avoid FPs on identifiers like `myhttp.get`, `myStatusCode`. CI baselines updated for `navigation_rules.dart` and `api_network_rules.dart`.
- **False positive reduction (Phase 2 batch 2):** **provider_rules:** `avoid_provider_for_single_value` — use exact set for Proxy/Multi skip (`_proxyOrMulti`); `prefer_selector_over_single_watch` — use regex `\.select\s*\(` instead of `bodySource.contains('.select(')`; `avoid_provider_value_rebuild` — use `typeName.endsWith('Provider')` instead of `typeName.contains('Provider')`. **permission_rules:** `require_location_permission_rationale` — word-boundary regex for rationale patterns (`_rationalePatterns`); `require_camera_permission_check` — word-boundary regex for camera check (`_cameraCheckPatterns`); `prefer_image_cropping` — word-boundary regex for cropper/crop/ImageCropper/cropImage. **api_network_rules:** `require_retry_logic` — word-boundary regex for http/dio/client and retry/maxRetries. CI baselines updated for `api_network_rules.dart`, `permission_rules.dart`, `packages/provider_rules.dart`.
- **False positive reduction (Phase 2 batch 3):** **permission_rules:** `prefer_image_cropping` — profile-context check uses word-boundary regex (`_profileContextKeywordPatterns`) instead of `bodySource.contains(keyword)`. **api_network_rules:** `require_connectivity_check` — word-boundary regex for HTTP and connectivity patterns (`_connectivityHttpPatterns`, `_connectivityCheckPatterns`); `require_request_timeout` — word-boundary regex for timeout config (`_timeoutConfigPatterns`). **async_rules:** `require_feature_flag_default` — exact target set (`_remoteConfigTargetNames`) via `extractTargetName` instead of `targetSource.contains`; DateTime UTC rule — regex for `.toUtc()`/`.utc`; stream listen and StreamController rules — `extractTargetName` + `endsWith('stream'|'controller')` instead of `targetSource.contains`. CI baselines: api_network_rules 126→114, async_rules 59→50; permission_rules removed (count 0).
- **False positive reduction (Phase 2 batch 4):** **widget_lifecycle_rules:** `require_scroll_controller_dispose`, `require_focus_node_dispose` — iteration disposal check uses `RegExp(r'\.dispose\s*\(\s*\)')` instead of `disposeBody.contains('.dispose()')`. **api_network_rules:** `prefer_http_connection_reuse` — word-boundary regex for client creation and `.close()` (`_clientCreationPatterns`, `_clientLocalVarPatterns`, `_closeCallPattern`); `avoid_redundant_requests` — `_buildMethodApiPatterns`, `_buildMethodCachingPatterns`; `require_response_caching` — `_getRequestPatterns`, `_responseCachingPatterns`, `_classCachePatterns`; `prefer_api_pagination` — `_paginationApiPatterns`, `_paginationParamPatterns`. CI baselines: api_network_rules 114→75, widget_lifecycle_rules 18→16, async_rules 50→47.
- **False positive reduction (Phase 2 batch 5):** **api_network_rules:** `require_offline_indicator` — `_connectivityTargetPatterns`, `_uiFeedbackPatterns` (word-boundary regex); `prefer_streaming_response` — `_responseTargetPatterns`, `_fileContextPatterns`, `_fileOpPatterns` for response/file context; `avoid_over_fetching` — regex for `.name`/`.title`/`.id`; `require_cancel_token` — `_cancelTokenHttpPatterns`, `_cancelTokenCancellationPatterns`, `_cancelTokenMountedPatterns`. CI baseline: api_network_rules 75→51.
- **False positive reduction (Phase 3 batch):** **animation_rules:** `require_animation_controller_dispose` — dispose check uses `isFieldCleanedUp(name, 'dispose', disposeMethodBody)` from `target_matcher_utils` instead of regex on `disposeBody` source. **async_rules:** `require_stream_controller_close` — `.close()`/`.dispose()` detection uses `RegExp(r'\.close\s*\(|\.dispose\s*\(')` instead of `bodySource.contains(...)`; `avoid_stream_subscription_in_field` — StreamSubscription field/type checks use exact type (`StreamSubscription` / `StreamSubscription?` / `StreamSubscription<...>`) and exact variable-name set plus `endsWith('Subscription')` instead of `contains('subscription'|'Subscription')`; `require_stream_subscription_no_leak` — cancel target type uses `startsWith('StreamSubscription')` instead of `contains('StreamSubscription')`.
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

### Added

- **Tests:** `test/fixture_lint_integration_test.dart` — runs `dart run custom_lint` on example_async and asserts output is parseable with `parseViolations`.
- **Missing fixtures (single-per-category):** Added fixtures and test list entries for: freezed (`avoid_freezed_any_map_issue`), notification (`prefer_local_notification_for_immediate`), type_safety (`avoid_redundant_null_check`), ui_ux (`prefer_master_detail_for_large`), widget_lifecycle (`require_init_state_idempotent`).
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

## [5.0.3]

### Added

- `avoid_string_env_parsing`: warns when `fromEnvironment()` is called without `defaultValue` (Recommended)
- `avoid_connectivity_equals_internet`: warns when `ConnectivityResult` is used as a proxy for internet access (Essential)
- `avoid_platform_specific_imports`: warns when `dart:io` is imported in shared/web-capable code (Recommended)
- `avoid_shared_prefs_sync_race`: warns when SharedPreferences writes are not awaited in async code (Recommended)
- `avoid_multiple_animation_controllers`: warns when a State class has 3+ AnimationController fields (Professional)
- `avoid_form_validation_on_change`: warns when `validate()` is called inside `onChanged` (Professional)
- `avoid_stack_trace_in_production`: warns when stack traces are exposed to users (OWASP M10) (Recommended)
- `avoid_expensive_did_change_dependencies`: warns when expensive operations run in `didChangeDependencies()` (Professional)
- `avoid_permission_request_loop`: warns when `Permission.request()` is called inside a loop (Professional)
- `avoid_entitlement_without_server`: warns when IAP purchases are verified client-side only (OWASP M1/M4) (Professional)
- `avoid_webview_cors_issues`: warns when `allowUniversalAccessFromFileURLs` or `allowFileAccessFromFileURLs` is set to `true` (OWASP M8/A05) (Professional)

### Fixed

- `prefer_trailing_comma_always`: suppress false positive when the last argument is a callback/closure whose body spans multiple lines
- `init` walkthrough: skipped stylistic rules now marked as reviewed so they are not re-prompted on subsequent runs
- `// ignore:` directives now work correctly on declarations with doc comments; previously, diagnostics reported on `MethodDeclaration`/`FunctionDeclaration`/`ClassDeclaration` nodes started at the doc comment offset, making `// ignore:` before the signature invisible to the analysis server (47 rules affected)
- `avoid_long_parameter_list`: diagnostic now highlights the parameter list instead of the entire declaration

### Changed

- Added `exampleBad`/`exampleGood` to 26 conflicting stylistic rules for clearer wizard descriptions

### Build Process

- `init` walkthrough: show GOOD example before BAD for clearer readability
- `init` walkthrough: restructured 77-rule "Opinionated prefer\_\* rules" bucket into 27 conflicting pick-one categories (e.g., `prefer_await_over_then` vs `prefer_then_over_await`) plus 32 non-conflicting opinionated rules
- `init` walkthrough: skip prompt now says "keeps current" to clarify the rule won't be re-asked

---

## [5.0.2]

### Fixed

- `prefer_list_first`: suppress false positives when the same collection is accessed with sibling indices (`list[0]` alongside `list[1]`), on assignment targets (`list[0] = value`), on String subscripts (`string[0]`), and on Map access (`map[0]`)
- `prefer_list_last`: same false positive suppression — assignment targets, String/Map types, and sibling index accesses
- `prefer_catch_over_on`: reversed rule logic — now only flags `on Object catch` and `on dynamic catch` (redundant, equivalent to bare `catch`), no longer flags specific `on` clauses like `on FormatException catch` which are intentional type filtering. Added quick fix to remove the redundant `on Object` clause.
- `avoid_dynamic_type`: exempt `dynamic` in type arguments (`List<dynamic>`, `Map<dynamic, dynamic>`), closure/lambda parameters, and for-in loop variables — eliminates false positives in JSON utility code
- `avoid_ignoring_return_values`: add `update`, `putIfAbsent`, `updateAll`, `addEntries` to safe-to-ignore list — these Map mutation methods are called for their side effect, not their return value
- `avoid_medium_length_files` (and all 8 file length rules): count only code lines, excluding comments and blank lines — well-documented files are no longer penalised for thorough dartdoc
- `avoid_long_functions`: count only code lines in function bodies, excluding comments and blank lines — well-documented functions are no longer penalised for thorough comments (v5)
- `prefer_no_commented_out_code`: tighten keyword and type-name patterns, add prose guard with strong-code-indicator bypass — fixes false positives on section headers (`// Iterable extensions`), inline prose (`// this is non-null`), and comments containing type names in natural language

### Removed

- `avoid_ignore_trailing_comment` rule, `MoveTrailingCommentFix` quick fix, and `trailingCommentOnIgnore` regex — the native Dart analyzer handles ignore directive trailing comments correctly, making this rule produce false positives
- Trailing-comment fixer functions from `bin/init.dart` (`_fixTrailingIgnoreComments`, `_splitIgnoreParts`, etc.) — existed only to support the removed rule
- `scripts/run_custom_lint_all.py` — obsolete v4 script
- `example/custom_lint.yaml` — v4 configuration artifact

### Changed

- All CLI tools (`bin/baseline.dart`, `bin/impact_report.dart`) now use `dart analyze` instead of `dart run custom_lint`
- YAML config examples updated from v4 `custom_lint:` format to v5 native `plugins: saropa_lints:` format across lib/, docs, and scripts
- Tier parser in `_analyze_pubspec.py` updated to read v5 `plugins.saropa_lints.diagnostics` structure
- Removed `_offer_custom_lint()` from publish script (no longer applicable)
- VSCode extension updated to run `dart analyze` instead of `dart run custom_lint`

---

## [5.0.1]

### Added

- Quick fixes for 5 blank-line formatting rules: `prefer_blank_line_before_case`, `prefer_blank_line_before_constructor`, `prefer_blank_line_before_method`, `prefer_blank_line_after_declarations`, `prefer_blank_lines_between_members`
- Test fixtures for 4 auto_route rules (`avoid_auto_route_context_navigation`, `avoid_auto_route_keep_history_misuse`, `require_auto_route_guard_resume`, `require_auto_route_full_hierarchy`)
- Test fixtures for `avoid_behavior_subject_last_value` (rxdart)
- Test fixtures for 3 migration rules (`avoid_asset_manifest_json`, `prefer_dropdown_initial_value`, `prefer_on_pop_with_result`)
- Unit test files for auto_route and rxdart rule categories
- Implemented `prefer_mock_verify` and `require_mock_http_client` fixture examples (replaced stubs)
- Uncommented `prefer_semantics_container` and `avoid_redundant_semantics` fixture code (added `container` parameter to Semantics mock)

### Fixed

- Publish report: test coverage "Overall" percentage now caps per-category fixture counts at rule counts, preventing excess fixtures from masking gaps
- `prefer_static_class`: no longer fires on `abstract final class` declarations (regression from beta.15 fix)
- `avoid_hardcoded_locale`: skip locale-pattern strings inside collection literals (Set, List, Map lookup data)
- `avoid_datetime_comparison_without_precision`: skip comparisons against compile-time constants (e.g., epoch sentinel checks)
- `avoid_unsafe_collection_methods`: strengthen guard detection with source-text fallback for length/isNotEmpty checks
- `avoid_medium_length_files`: exempt files containing only `abstract final` utility namespace classes
- `prefer_single_declaration_per_file`: exempt files where all classes are `abstract final` static-only namespaces
- `prefer_no_continue_statement`: exempt early-skip guard pattern (`if (cond) { continue; }` at top of loop body)

### Changed

- `avoid_high_cyclomatic_complexity`: raise threshold from 10 to 15 to align with industry standards (SonarQube, ESLint)

---

## [5.0.0-beta.15]

### Added

- `avoid_cached_image_web`: warns when CachedNetworkImage is used inside a `kIsWeb` branch where it provides no caching benefit (Recommended tier)
- `avoid_clip_during_animation`: warns when Clip widgets are nested inside animated widgets, causing expensive per-frame rasterization (Professional tier)
- `avoid_auto_route_context_navigation`: warns when string-based `context.push`/`context.go` is used in auto_route projects instead of typed routes (Professional tier)
- `avoid_auto_route_keep_history_misuse`: warns when `replaceAll`/`popUntilRoot` is used outside authentication flows, destroying navigation history (Professional tier)
- `avoid_accessing_other_classes_private_members`: warns when code accesses another class's private members through same-file library privacy (Professional tier)
- `avoid_closure_capture_leaks`: warns when `setState` is called inside Timer/Future.delayed callbacks without a `mounted` check (Professional tier, quick fix)
- `avoid_behavior_subject_last_value`: warns when `.value` is accessed on a BehaviorSubject inside an `isClosed` true-branch (Professional tier)
- `avoid_cache_stampede`: warns when async methods use a Map cache without in-flight request deduplication (Professional tier)
- `avoid_deep_nesting`: warns when code blocks are nested more than 5 levels deep (Professional tier)
- `avoid_high_cyclomatic_complexity`: warns when functions exceed cyclomatic complexity of 10 (Professional tier)
- `avoid_void_async`: warns when async functions return `void` instead of `Future<void>` (Recommended tier)
- `avoid_redundant_await`: warns when `await` is used on a non-Future expression (Recommended tier)
- `avoid_unused_constructor_parameters`: warns when constructor parameters are not stored or used (Recommended tier)
- `avoid_returning_null_for_void`: warns when `return null` is used in void functions (Recommended tier)
- `avoid_returning_null_for_future`: warns when `null` is returned from non-async Future functions (Recommended tier)
- `avoid_shadowing_type_parameters`: warns when method type parameters shadow class type parameters (Recommended tier)
- `avoid_redundant_null_check`: warns when non-nullable values are compared to null (Recommended tier)
- `avoid_collection_mutating_methods`: warns when collections are mutated in-place inside setState (Professional tier)
- `avoid_equatable_nested_equality`: warns when mutable collections are included in Equatable props (Professional tier)
- `avoid_getx_rx_nested_obs`: warns when GetX Rx observables are nested (Professional tier)
- `avoid_freezed_any_map_issue`: warns when @freezed class with fromJson lacks @JsonSerializable(anyMap: true) (Professional tier)
- `avoid_hive_datetime_local`: warns when DateTime is stored in Hive without UTC conversion (Professional tier)
- `avoid_hive_type_modification`: warns when @HiveField indices are duplicated (Professional tier)
- `avoid_hive_large_single_entry`: warns when large objects are stored as single Hive entries (Professional tier)
- `require_auto_route_guard_resume`: warns when AutoRouteGuard may not call resolver.next() on all paths (Essential tier)
- `require_auto_route_full_hierarchy`: warns when push() is used instead of navigate() in auto_route (Essential tier)
- `avoid_firebase_user_data_in_auth`: warns when too many custom claims are accessed from Firebase auth tokens (Professional tier)
- `require_firebase_app_check_production`: warns when Firebase is initialized without App Check (Professional tier)

### Fixed

- `avoid_god_class`: false positive on static-constant namespace classes — `static const` and `static final` fields are now excluded from the field count since they represent compile-time constants, not instance state
- `prefer_static_class`: conflicting diagnostic with `prefer_abstract_final_static_class` on classes with private constructors — `prefer_static_class` now defers to `prefer_abstract_final_static_class` when a private constructor is present
- `avoid_similar_names`: false positive on single-character variable pairs (`y`, `m`, `d`, `h`, `s`) — edit distance is always 1 for any two single-char names, which is not meaningful; confusable-char detection (1/l, 0/O) still catches genuinely dangerous cases
- `avoid_unused_assignment`: false positive on definite assignment via if/else branches — assignments in mutually exclusive branches of the same if/else are now recognized as alternatives, not sequential overwrites

---

## [5.0.0-beta.14]

### Fixed

- `avoid_variable_shadowing`: false positive on sequential for/while/do loops reusing the same variable name — loop variables are scoped to their body and don't shadow each other
- `avoid_unused_assignment`: false positive on conditional reassignment (`x = x.toLowerCase()` inside if-blocks) — now skips loop-body assignments, may-overwrite conditionals, and self-referencing RHS
- `prefer_switch_expression`: false positive on switch cases containing control flow (`if`/`for`/`while`) or multiple statements — also detects non-exhaustive switches with post-switch code
- `no_magic_number`: false positive on numeric literals used as default parameter values — the parameter name provides context, making the number self-documenting
- `avoid_unnecessary_to_list` / `avoid_large_list_copy`: false positive when `.toList()` is required by return type, method chain, expression function body, or argument position
- `prefer_named_boolean_parameters`: false positive on lambda/closure parameters — their signature is constrained by the expected function type
- `avoid_unnecessary_nullable_return_type`: false positive on ternary expressions with null branches, map `[]` operator, and nullable method delegation — now checks static type nullability recursively
- `avoid_duplicate_string_literals` / `avoid_duplicate_string_literals_pair`: false positive on domain-inherent literals (`'true'`, `'false'`, `'null'`, `'none'`) that are self-documenting
- `avoid_excessive_expressions`: false positive on guard clauses (early-return if-statements) and symmetric structural patterns — guard clauses now allowed up to 10 operators, symmetric repeating patterns are exempt
- `prefer_digit_separators`: false positive on 5-digit numbers — threshold raised from 10,000 to 100,000 (6+ digits) to match common style guide recommendations
- `require_list_preallocate`: false positive when `List.add()` is inside a conditional branch within a loop — preallocation is impossible when the number of additions is data-dependent

---

## [5.0.0-beta.13]

### Fixed

- `prefer_match_file_name`: false positive on Windows — backslash paths caused file name extraction to fail, reporting every correctly-named class
- `prefer_match_file_name`: false positive when file has multiple public classes — second class was reported even when first class matched
- `avoid_unnecessary_nullable_return_type`: false positive on expression-bodied functions — ternaries with null branches, map lookups, and other nullable expressions were not recognized
- `prefer_unique_test_names`: false positives when same test name appears in different `group()` blocks — now builds fully-qualified names from group hierarchy, matching Flutter's test runner behavior
- `avoid_dynamic_type`: false positives for `Map<String, dynamic>` — the canonical Dart JSON type is now exempt
- `no_magic_number_in_tests`: expanded allowed integers to include 6–31 (day/month numbers), common round numbers (10000, 100000, 1000000), and exemptions for DateTime constructor arguments and expect() calls
- `no_magic_string_in_tests`: false positives for test fixture data — strings passed as arguments to functions under test and strings in expect() calls are now exempt
- `avoid_large_list_copy`: false positives for required copies — `List<T>.from()` with explicit type arguments (type-casting pattern) is now exempt; `.toList()` is exempt when returned, assigned, or otherwise structurally required

### Changed

- Merged duplicate rule `prefer_sorted_members` into `prefer_member_ordering`; `prefer_sorted_members` continues to work as a config alias
- Clarified correction messages for `prefer_boolean_prefixes`, `prefer_descriptive_bool_names`, and `prefer_descriptive_bool_names_strict` to distinguish scope (fields-only vs all booleans)

### Publishing

- Publish audit: consolidated quality checks into a single pass/warn/fail list instead of separate subsections per check
- Publish audit: US English spelling check displayed as a simple bullet instead of a standalone subsection
- Publish audit: bug reports grouped by status (done, in progress, unsolved) with scaled bars per group
- Publish audit: test coverage columns dynamically aligned to longest category name
- Init: "what's new" summary now shows all items (no `+N more` or section truncation) — only individual lines are truncated at 78 chars
- Init: tier default changed from `comprehensive` to `essential` for fresh setups; re-runs default to the previously selected tier
- Init: stale config version warning now tells the user how to fix it (`re-run "dart run saropa_lints" to update`)
- Init: stylistic walkthrough shows per-rule progress counter (`4/120 — 3%`) and `[quick fix]` indicator for rules with IDE auto-fixes
- Init: stylistic walkthrough rule descriptions rendered in default terminal color instead of dim gray for readability

---

## [5.0.0-beta.12]

### Added

- Init: interactive stylistic rule walkthrough — shows code examples and lets users enable/disable each rule individually with y/n/skip/abort support and resume via `[reviewed]` markers
- Init: `--stylistic-all` flag for bulk-enabling all stylistic rules (replaces old `--stylistic` behavior); `--no-stylistic` to skip walkthrough; `--reset-stylistic` to clear reviewed markers
- Init: auto-detect project type from pubspec.yaml — Flutter widget rules are skipped for pure Dart projects, package-specific rules filtered by dependencies
- `SaropaLintRule`: `exampleBad`/`exampleGood` properties for concise terminal-friendly code snippets (40 rules covered)
- `tiers.dart`: `flutterStylisticRules` set for widget-specific stylistic rules filtered by platform
- Init: "what's new" summary shown during `dart run saropa_lints:init`, with line truncation and a link to the full changelog
- New rule: `prefer_sorted_imports` (Comprehensive) — detects unsorted imports within each group (dart, package, relative) with quick fix to sort A-Z
- New rule: `prefer_import_group_comments` (Stylistic) — detects missing `///` section headers between import groups with quick fix to add them
- New rule: `avoid_asset_manifest_json` (Essential) — detects usage of removed `AssetManifest.json` path (Flutter 3.38.0); runtime crash since the file no longer exists in built bundles
- New rule: `prefer_dropdown_initial_value` (Recommended) — detects deprecated `value` parameter on `DropdownButtonFormField`, suggests `initialValue` (Flutter 3.35.0) with quick fix
- New rule: `prefer_on_pop_with_result` (Recommended) — detects deprecated `onPop` callback on routes, suggests `onPopWithResult` (Flutter 3.35.0) with quick fix

### Fixed

- `no_empty_string`: only flag empty strings in equality comparisons (`== ''`, `!= ''`) where `.isEmpty`/`.isNotEmpty` is a viable alternative — skip return values, default params, null-coalescing, replacement args
- `prefer_cached_getter`: skip methods inside extensions and extension types (cannot have instance fields) and static methods (cannot cache to instance fields)
- `prefer_compute_for_heavy_work`: only flag encode/decode/compress calls inside widget lifecycle methods (`build`, `initState`, etc.) — library utility methods have no UI thread to protect
- `prefer_keep_alive`: check for `TabBarView`/`PageView` identifiers instead of naive `contains('Tab')`/`contains('Page')` substring matching
- `prefer_prefixed_global_constants`: case-insensitive descriptive pattern check for lowerCamelCase constants; expand pattern list (width, height, padding, etc.); narrow threshold to only flag names < 5 chars
- `prefer_secure_random`: only flag `Random()` in security-related contexts (variable/method names containing token, password, encrypt, etc.); skip `.shuffle()` usage and literal-seeded constructors
- `prefer_static_method`: skip methods inside extensions and extension types (cannot be made static in Dart)
- `require_currency_code_with_amount`: split into strong (price, amount, cost, fee) and weak (total, balance, rate) monetary signals; weak signals require 2+ matches with double/Decimal type; skip non-monetary class names (stats, count, metric, score, etc.)
- `require_dispose_pattern`: skip classes with `const` constructors (hold borrowed references, not owned resources)
- `require_envied_obfuscation`: skip class-level `@Envied` warning when all `@EnviedField` annotations explicitly specify `obfuscate`
- `require_https_only_test`: skip HTTP URLs inside test infrastructure calls (`test()`, `expect()`, `group()`, etc.) since URL utility tests must exercise HTTP
- `require_ios_callkit_integration`: replace brand name string matching (Agora, Twilio, Vonage, WebRTC) with import-based detection for 13 VoIP packages; keep only unambiguous technical terms for string matching
- `avoid_barrel_files`: skip files with `library` directive and the mandatory package entry point (`lib/<package_name>.dart`)
- `avoid_duplicate_number_elements`: only flag `Set` literals — duplicate numeric values in `List` literals are intentional (e.g. days-in-month)
- `avoid_ignoring_return_values`: skip property setter assignments (`obj.prop = value`) which have no return value
- `avoid_money_arithmetic_on_double`: use camelCase word-boundary matching instead of substring matching to avoid false positives on `totalWidth`, `frameRate`, etc.
- `avoid_non_ascii_symbols`: narrow from all non-ASCII to invisible/confusable characters only (zero-width, invisible formatters, non-standard whitespace)
- `avoid_static_state`: skip `static const` and `static final` with known-immutable types (`RegExp`, `DateTime`, etc.); retain detection of `static final` mutable collections
- `avoid_stream_subscription_in_field`: skip `.listen()` calls whose return value is passed as an argument (e.g. `subs.add(stream.listen(...))`)
- `avoid_string_concatenation_l10n`: skip numeric-only interpolated strings (e.g. `'$a / $b'`) that contain no translatable word content
- `avoid_unmarked_public_class`: skip classes where all constructors are private (extension already prevented)

### Package Publishing Changes

- Publish audit: added 3 new blocking checks — `flutterStylisticRules` subset validation, `packageRuleSets` tier consistency, `exampleBad`/`exampleGood` pairing
- Publish audit: doc comment auto-fix (angle brackets, references) now runs during audit step instead of only during analysis step

---

## [5.0.0-beta.11]

### Changed

- CLI defaults to `init` command when run without arguments (`dart run saropa_lints` now equivalent to `dart run saropa_lints init`)
- Publish script: `dart format` now targets specific top-level paths, excluding `example*/` directories upfront instead of tolerating exit-code 65 after the fact
- Publish script: roadmap summary now includes color-coded bug report breakdown (unsolved/categorized/resolved) from sibling `saropa_dart_utils/bugs/` directory
- Deferred `avoid_misused_hooks` rule removed from ROADMAP_DEFERRED (hook rules vary by context — not viable as static lint)

---

## [5.0.0-beta.10]

### Fixed

- Init: `_stylisticRuleCategories` synced with `tiers.stylisticRules` — removed obsolete `prefer_async_only_when_awaiting`, added ~40 rules to proper categories instead of "Other stylistic rules" catch-all
- Init: obsolete stylistic rules in consumer `analysis_options_custom.yaml` are now cleaned up during rebuild, with warnings for user-enabled rules being dropped
- Init: stylistic rules redundantly placed in RULE OVERRIDES section are detected — interactive prompt offers to move them to the STYLISTIC RULES section
- Init: `_buildStylisticSection()` now filters against `tiers.stylisticRules` to prevent future category/tier desyncs
- `dart analyze` exit codes 1-2 (issues found) no longer reported as "failed" — only exit code 3+ (analyzer error) is treated as failure
- Progress bar stuck at ~83% — recalibration threshold no longer inflates expected file count when discovery overcounts
- Progress bar now shows 100% completion before the summary box
- Publish script: restored post-publish version bump (pubspec + `[Unreleased]` section) — accidentally removed in v4.9.17 refactor
- Publish script: optional `_offer_custom_lint` prompt no longer blocks success status or timing summary on interrupt

### Changed

- Init log (`*_saropa_lints_init.log`) now contains only setup/configuration data; raw `dart analyze` output is no longer mixed in — the plugin's report (`*_saropa_lint_report.log`) covers analysis results
- Init log written before analysis prompt so the path is available upfront
- Plugin report path displayed after analysis completes (with retry for async flush)
- Old report files in `reports/` root are automatically migrated to `reports/YYYYMMDD/` date subfolders during init
- Stream drain and exit code now awaited together via `Future.wait` to prevent interleaved output
- Persistent cache files (`rule_version_cache.json`, export directories) moved from `reports/` root to `reports/_cache/` subfolder

---

## [5.0.0-beta.9]

### Fixed

- Plugin silently ignored by `dart analyze` — generated `analysis_options.yaml` was missing the required `version:` key under `plugins: saropa_lints:`; the Dart SDK's plugin loader returns `null` when no version/path constraint is present, causing zero lint issues to be reported
- Analysis server crash loop (FormatException) — `ProgressTracker` was writing ANSI progress bars to `stdout`, which corrupts the JSON-RPC protocol used by the analysis server; all output now routes through `stderr`

### Added

- Pre-flight validation checks in `init`: verifies pubspec dependency, Dart SDK >= 3.6, and audits existing config for stale `custom_lint:` sections or missing `version:` keys
- Post-write validation: confirms the generated file has `plugins:`, `version:`, `diagnostics:` sections and expected rule count
- Analysis results now captured in the init log file (previously only shown on terminal)
- Log summary section with version, tier, rule counts, and collected warnings

### Changed

- `dart analyze` output is now captured and streamed (was `inheritStdio` with no capture)
- Log file write deferred until after analysis completes so the report includes everything
- All tier YAML files now include `version: "^5.0.0-beta.8"` for direct-include users
- All report-generating scripts now write to `reports/YYYYMMDD/` date subfolders with timestamped filenames (todo audit, full audit, lint candidates, rule versions)

### Archive

- Rules 4.15.1 and older moved to [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md)

---

## [5.0.0-beta.8]

### Changed

- Version bump

---

## [5.0.0-beta.7]

### Added

- Init log file now includes a detailed rule-by-rule report listing every rule with its status, severity, tier, and any override/filter notes

### Changed

- Report files now write into `reports/YYYYMMDD/` date subfolders instead of flat in `reports/` — reduces clutter when many reports accumulate
- `--tier` / `--output` flags without a value now warn instead of silently using defaults
- `dart run saropa_lints:init` without `--tier` now prompts for interactive tier selection (was silently defaulting to comprehensive)

### Fixed

- `.pubignore` pattern `test/` was excluding `lib/src/fixes/test/` from published package — anchored to `/test/` so only the root test directory is excluded; this caused `dart run saropa_lints:init` to fail with a missing import error for `replace_expect_with_expect_later_fix.dart`
- Publish script `dart format` step failed on fixture files using future language features (extension types, digit separators, non-ASCII identifiers) — now tolerates exit code 65 when all unparseable files are in example fixture directories

---

## [5.0.0-beta.6]

### Added

- Quick fix for `require_subscription_status_check` — inserts TODO reminder to verify subscription status in build methods
- `getLineIndent()` utility on `SaropaFixProducer` base class for consistent indentation in fix output

### Changed

- Moved generated export folders (`dart_code_exports/`, `dart_sdk_exports/`, `flutter_sdk_exports/`) and report caches from `scripts/` to `reports/` — scripts now write output to the gitignored `reports/` directory, keeping `scripts/` clean
- Filled TODO placeholders in 745 fixture files across all example directories — core and async fixtures now have real bad/good triggering code; widget, package, and platform fixtures have NOTE placeholders documenting rule requirements
- Expanded ROADMAP task backlog with 138 detailed implementation specs
- Deduplicated `_getIndent` from 5 fix files into shared `SaropaFixProducer.getLineIndent()`

### Fixed

- Audit script `get_rules_with_corrections()` now handles variable-referenced rule names (e.g. `LintCode(_name, ...)`) — previously undercounted correction messages by 1 (`no_empty_block`)
- OWASP M2 coverage now correctly reported as 10/10 — audit scanner regex updated to match both single-line and dart-formatted multiline `OwaspMapping` getters; `avoid_dynamic_code_loading` and `avoid_unverified_native_library` (M2), `avoid_hardcoded_signing_config` (M7), and `avoid_sudo_shell_commands` (M1) were previously invisible to the scanner
- Completed test fixtures for `avoid_unverified_native_library` and `avoid_sudo_shell_commands` (previously empty stubs)
- Removed 4 dead references to unimplemented rule classes from registration and tier files (`require_ios_platform_check`, `avoid_ios_background_fetch_abuse`, `require_method_channel_error_handling`, `require_universal_link_validation`) — tracked as `bugs/todo_001` through `todo_004`

---

## [5.0.0-beta.5]

### Added

- Auto-migration from v4 (custom_lint) to v5 (native plugin) — `dart run saropa_lints:init` auto-detects and converts v4 config, with `--fix-ignores` for ignore comment conversion
- Plugin reads `diagnostics:` section from `analysis_options.yaml` to determine which rules are enabled/disabled — previously the generated config was not consumed by the plugin
- Registration-time rule filtering — disabled rules are never registered with the analyzer, improving startup performance

### Fixed

- Plugin now respects rule enable/disable config from `dart run saropa_lints:init` — previously all rules were registered unconditionally regardless of tier selection
- V4 migration no longer imports all rule settings as overrides — only settings that differ from the selected v5 tier defaults are preserved, preventing mass rule disablement
- Init script scans and auto-fixes broken ignore comments — detects trailing explanations (`// ignore: rule // reason` or `// ignore: rule - reason`) that silently break suppression, and moves the text to the line above
- Quick fix support for 108 rules via native `SaropaFixProducer` system — enables IDE lightbulb fixes and `dart fix --apply`
- 3 reusable fix base classes: `InsertTextFix`, `ReplaceNodeFix`, `DeleteNodeFix` in `lib/src/fixes/common/`
- 108 individual fix implementation files in `lib/src/fixes/<category>/`, all with real implementations (zero TODO placeholders)
- Test coverage for all 95 rule categories (Phase 1-3): every category now has a dedicated `test/*_rules_test.dart` file with fixture verification and semantic test stubs
- 506 missing fixture stubs across all example directories (Phase 1-4)
- 12 new package fixture directories: flutter_hooks, workmanager, supabase, qr_scanner, get_it, geolocator, flame, sqflite, graphql, firebase, riverpod, url_launcher

### Changed

- PERFORMANCE.md rewritten for v5 native plugin architecture — replaced all custom_lint references with `dart analyze`, updated rule counts, documented lazy rule instantiation and compile-time constant tier sets, added rule deferral info

### Fixed

- Test fixture paths for bloc, firebase, riverpod, provider, and url_launcher now point to individual category directories instead of shared `packages/` directory
- Platform fixture paths reorganized from shared `platforms/` directory to per-platform directories (`ios/`, `macos/`, `android/`, `web/`, `linux/`, `windows/`) — fixes 0% coverage report for all platform categories
- Coverage script fallback search for fixture files in subdirectories, with prefix-match anchoring and OS error handling

---

## [5.0.0-beta.4]

### Fixed

- Untrack `.github/copilot-instructions.md` — was gitignored but tracked, causing `dart pub publish --dry-run` to exit 65 (warning)
- Publish workflow dry-run step now tolerates warnings (exit 65) but still fails on errors (exit 66)
- Publish script now waits for GitHub Actions workflow to complete and reports real success/failure — previously printed "PUBLISHED" immediately without checking CI status

---

## [5.0.0-beta.3]

### Fixed

- Add `analyzer` as explicit dependency — `dart pub publish` rejected transitive-only imports, causing silent publish failure
- Remove `|| [ $? -eq 65 ]` from publish workflow — was silently swallowing publish failures

---

## [5.0.0-beta.2]

### Fixed

- Publish script regex patterns updated for v5 positional `LintCode` constructor — tier integrity, audit checks, OWASP coverage, prefix validation, and correction message stats now match both v5 positional and v4 named parameter formats
- Publish script version utilities now support pre-release versions (`5.0.0-beta.1` → `5.0.0-beta.2`) — version parsing, comparison, pubspec read/write, changelog extraction, and input validation all handle `-suffix.N` format

---

## [5.0.0-beta.1] — Native Plugin Migration

Migrated from `custom_lint_builder` to the native `analysis_server_plugin` system. This is a **breaking change** for consumers (v4 → v5).

**Why this matters:**

- **Quick fixes now work in IDE** — the old analyzer_plugin protocol never forwarded fix requests to custom_lint plugins (Dart SDK #61491). The native system delivers fixes properly.
- **Per-file filtering is enforced** — 425+ uses of `applicableFileTypes`, `requiredPatterns`, `requiresWidgets`, etc. were defined but never checked. Now enforced via `SaropaContext._wrapCallback()`, cached per file.
- **Future-proof** — the old `analyzer_plugin` protocol is being deprecated (Dart SDK #62164). custom_lint was the primary client.
- **~18K lines removed** — native API eliminates boilerplate (no more `CustomLintResolver`/`ErrorReporter`/`CustomLintContext` parameter triples).

### Added

- Native plugin entry point (`lib/main.dart`) with `SaropaLintsPlugin`
- `SaropaFixProducer` base class for quick fixes (`analysis_server_plugin`)
- `fixGenerators` getter on `SaropaLintRule` for automatic fix registration
- `SaropaContext` with per-file filtering wrapper on all 83 `addXxx()` methods
- `CompatVisitor` bridging callbacks to native `SimpleAstVisitor` dispatch
- PoC quick fixes: `CommentOutDebugPrintFix`, `RemoveEmptySetStateFix`
- Native framework provides ignore-comment fixes automatically (no custom code needed)
- Config loader (`config_loader.dart`) reads `analysis_options_custom.yaml` at startup
- Severity overrides via `severities:` section (ERROR/WARNING/INFO/false per rule)
- Baseline suppression wired into reporter — checks `BaselineManager` before every report
- Impact tracking — every violation recorded in `ImpactTracker` by impact level
- Progress tracking — files and violations tracked in `ProgressTracker` per file/rule
- `Plugin.start()` lifecycle hook for one-time config loading
- Tier preset YAML files updated to native `plugins: saropa_lints: diagnostics:` format
- Migration guide (`MIGRATION_V5.md`) for v4 to v5 upgrade

### Changed

- `bin/init.dart` generates native `plugins:` format (was `custom_lint:`)
- Tier presets use `diagnostics:` map entries (was `rules:` list entries)
- Init command runs `dart analyze` after generation (was `dart run custom_lint`)
- All 96 rule files migrated to native `AnalysisRule` API
- `SaropaLintRule` now extends `AnalysisRule` (was `DartLintRule`)
- `LintCode` uses positional constructor: `LintCode('name', 'message')` (was named params)
- `runWithReporter` drops `CustomLintResolver` parameter
- `context.addXxx()` replaces `context.registry.addXxx()`
- `reporter.atNode(node)` replaces `reporter.atNode(node, code)` (code is implicit)
- Dependencies: `analysis_server_plugin: ^0.3.3` replaces `custom_lint_builder`
- README updated for v5: `dart analyze` replaces `dart run custom_lint`, tier preset includes, v4 migration FAQ

### Removed

- `custom_lint_builder` dependency and `lib/custom_lint_client.dart`
- Redundant PoC files (`saropa_analysis_rule.dart`, `poc_rules.dart`, `saropa_reporter.dart`)
- Old v4 ignore-fix classes — superseded by native framework

---

## [4.15.1] and Earlier

For details on the initial release and versions 0.1.0 through 4.15.1, please refer to [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md).

---
## [Unreleased]

---
## [6.0.8]

### Changed
- Version bump

