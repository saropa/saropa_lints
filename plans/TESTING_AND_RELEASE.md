# Testing & Release Plan

Consolidated from TESTING_ISSUES.md, task-phase6-testing-release.md, and UNIT_TEST_COVERAGE.md.

**Last updated:** 2026-05-08  
**Scope:** All lint rules in `lib/src/rules/`, tests in `test/`, and v5 release readiness.  
**Goal:** Expand behavioral fixture integration tests, close remaining fixture gaps, verify IDE integration, prove quick-fix application end-to-end.

## Execution snapshot

### Release gates (open)

- [ ] **REL-01 (P0)** Fixture coverage gate to target threshold (or explicit documented exemption delta).
- [ ] **REL-02 (P0)** Quick-fix application proof (D1-D5) with reproducible test evidence.
- [ ] **REL-03 (P0)** IDE integration manual sign-off checklist (E1-E5) fully filled and archived.
- [ ] **REL-04 (P1)** Regression/perf baseline refresh captured before next release-class cut.

### Next 3 (ordered)

- [x] **REL-N1 (P0)** Complete D1-D3 fix-application tests and land in CI. (Verified 2026-05-08 via `dart test test/scan/fix_application_smoke_test.dart test/scan/fix_application_dart_fix_dry_run_test.dart`)
- [ ] **REL-N2 (P0)** Run and record E1-E5 manual IDE validation.
- [x] **REL-N3 (P1)** Refresh publish audit numbers and update this document's gate table. (Snapshot **2026-05-08:** implemented rules **2158**; audit quick-fix registrations **462** (`get fixGenerators` occurrences per `get_implemented_rules`); fixture coverage **1993 / 2154** rule-category instances (**92.5%**); rules with no fix producer **1698** / **109** files — `python scripts/list_rules_without_fixes.py`.)

### REL-N1 implementation slice (active)

- [ ] Add/verify one replace-path assertion in `test/scan/fix_application_smoke_test.dart`.
- [ ] Add/verify one delete-path assertion in `test/scan/fix_application_smoke_test.dart`.
- [ ] Add/verify one insert-path assertion in `test/scan/fix_application_smoke_test.dart`.
- [ ] Ensure test names map to plan IDs (D1/D2/D3) for audit traceability.

Fixture coverage for the 27 reviewed categories and rule instantiation tests for 108 categories are complete (see `bugs/history/`).

---

## 1. Current Status

Verified from the working tree on 2026-05-08 (see §10 for the verification commands). Metrics below come from `scripts.modules._audit_checks.get_implemented_rules` and `scripts.modules._rule_metrics.display_test_coverage` logic (fixture ratio uses capped per-category totals).

| Item | Status | Notes |
|------|--------|-------|
| Behavioral tests (linter on code) | **In progress** | `fixture_lint_integration_test.dart`: 18 compile-time rules asserted via `dart analyze`; 56-rule `custom_lint` set when `dart run custom_lint` is available |
| Publish report "Fixtures" metric | **<100%** | **92.5%** (**1993** / **2154** rule-category instances); split `code_quality_*` counting fixed in `_rule_metrics.py` (§4) |
| Quick fix migration (native plugin) | **Complete** | **462** rule classes wire `fixGenerators` (audit scan); 221 `SaropaFixProducer` subclasses across `lib/src/fixes/**` (structural migration); **0** `extends DartFix` remain in `lib/`. Verify with: `Grep "extends DartFix" lib/` |
| IDE integration testing | **Not started** | §5 |
| Regression / performance baselines | **Not started** | §6 |

---

## 2. Disabled Tests

~~These fixture files have compile errors and are temporarily disabled.~~ **All three repaired 2026-05-01** (plan §10 B1-B3). Each fixture now compiles cleanly under `dart analyze` with the BAD case re-enabled and the GOOD case restored:

| Was | File | Repair |
|-----|------|--------|
| `super_formal_parameter_without_associated_positional` | `example/lib/code_quality/prefer_redirecting_superclass_constructor_fixture.dart` | Added local `Parent(this.name)` so the GOOD super-formal-parameter form resolves. |
| `const_constructor_with_non_const_super` | `example_packages/lib/packages/avoid_bloc_event_mutation_fixture.dart` | Added local `abstract class MyEvent { const MyEvent(); }` so the GOOD const subclass compiles. |
| `implicit_super_initializer_missing_arguments` | `example_packages/lib/packages/require_bloc_initial_state_fixture.dart` | Added local `Bloc<E,S>` mock with optional positional state arg so the BAD case (no super initializer) compiles and exercises the rule. |

---

## 3. Quick Fix Migration (DONE)

The native-plugin fix migration is complete. As of 2026-04-30:

- `Grep "extends DartFix" lib/` returns **0** matches (verified).
- `Grep "extends SaropaFixProducer" lib/` returns **221 files / 249 occurrences** (verified). Several rule files wire multiple producers (`widget_patterns_require_rules.dart`: 5; `migration_rules.dart`: 11; `firebase_rules.dart`: 2).
- The historic seed pair (`CommentOutDebugPrintFix`, `RemoveEmptySetStateFix`) is now a tiny fraction of the wired set.

What remains to **prove** the migration (separate from migrating it):

- End-to-end "fix shows in VS Code lightbulb" verification — see §5.
- "Fix application produces expected output" automation — see §10 §F (no current Dart-level test exercises a `SaropaFixProducer` against a fixture and diffs the output).
- Coverage gap analysis — the audit script reports rules that still have **no** fix at all (separate from migration). Run `python scripts/list_rules_without_fixes.py` and triage from `plans/QUICK_FIX_PLAN.md` Part 1.

---

## 4. Publish Report Fixtures < 100%

### 4.1 Split `code_quality_*` fixture counting (done)

**File:** `scripts/modules/_rule_metrics.py` — `_count_fixtures_for_category`

Four categories (`code_quality_avoid`, `code_quality_control_flow`, `code_quality_prefer`, `code_quality_variables`) share `example/lib/code_quality/` (flat `*_fixture.dart` files). An explicit early branch intersects on-disk fixture basenames with each file’s `rule_names` so totals are not reused across split categories. Regression tests: `scripts/tests/test_rule_metrics.py`.

Remaining sub-100% overall percentage reflects **real** missing fixtures (and exempt categories), not the old double-counting bug.

---

## 5. IDE Integration Testing

| Test | Status | Notes |
|------|--------|-------|
| VS Code squiggles appear | TODO | Verify diagnostics show inline |
| Problems panel populated | TODO | Verify rule violations listed |
| Quick fixes appear (lightbulb) | TODO | **Primary motivation** — verify fixes show in VS Code |
| Quick fixes apply correctly | TODO | Verify applied fix produces correct code |
| `dart analyze` integration | TODO | Verify rules run via CLI |
| `dart fix --apply` integration | TODO | Verify bulk fix application |

---

## 6. Regression & Performance Testing

### Regression

| Test | Status |
|------|--------|
| v4 vs v5 output comparison | TODO |
| No false positive regressions | TODO |
| No false negative regressions | TODO |

### Performance

| Test | Status |
|------|--------|
| Benchmark vs custom_lint | TODO |
| Memory usage comparison | TODO |
| IDE responsiveness (time-to-squiggle) | TODO |

---

## 7. Fixture Paths Reference

When adding: rule must be implemented and BAD example must trigger the linter. No stubs. Validate with `dart run custom_lint` in the example package.

| Category | Rule(s) | Directory |
|----------|---------|-----------|
| architecture | ~~`prefer_builder_pattern`~~ | Rule not implemented; do not add fixture |
| async | `avoid_void_async` | `example_async/lib/async/` |
| class_constructor | `prefer_final_fields_always` | `example_core/lib/class_constructor/` |
| config | `prefer_compile_time_config`, `prefer_flavor_configuration` | `example_async/lib/config/` |
| connectivity | `prefer_connectivity_debounce` | `example_async/lib/connectivity/` |
| freezed | `prefer_freezed_union_types` | `example_packages/lib/freezed/` |
| json_datetime | `prefer_correct_json_casts` | `example_async/lib/json_datetime/` |
| navigation | `prefer_go_router_builder` | `example_widgets/lib/navigation/` |
| auto_route | `prefer_auto_route_path_params_simple`, `prefer_auto_route_typed_args` | `example_packages/lib/auto_route/` |
| bloc | `avoid_cubit_usage` | `example_packages/lib/bloc/` |
| firebase | `prefer_firebase_transaction_for_counters`, `prefer_correct_topics`, `prefer_deep_link_auth` | `example_packages/lib/firebase/` |
| geolocator | `prefer_geolocation_coarse_location` | `example_packages/lib/geolocator/` |
| getx | `avoid_getx_rx_nested_obs` | `example_packages/lib/getx/` |
| riverpod | `avoid_riverpod_string_provider_name` | `example_packages/lib/riverpod/` |
| performance | `prefer_disk_cache_for_persistence` | `example_async/lib/performance/` |
| record_pattern | `prefer_class_destructuring` | `example_core/lib/record_pattern/` |
| return | `avoid_returning_this` | `example_core/lib/return/` |
| stylistic | `prefer_expression_body_getters`, `prefer_block_body_setters` | `example_style/lib/stylistic/` |
| theming | `prefer_dark_mode_colors`, `prefer_high_contrast_mode` | `example_widgets/lib/theming/` |
| widget_layout | `prefer_flex_for_complex_layout`, `prefer_find_child_index_callback` | `example_widgets/lib/widget_layout/` |
| widget_patterns | `avoid_bool_in_widget_constructors`, `avoid_unnecessary_containers`, `prefer_const_literals_to_create_immutables` | `example_widgets/lib/widget_patterns/` |

---

## 8. Release Plan

The native-plugin migration referenced in earlier drafts of this plan as "v5" already shipped within the active 12.x line (`SaropaFixProducer` introduced 2026-02-16). Current release target is therefore quality gating against the live 12.x series, not a version-major rewrite.

| Milestone | Gate | Status | Description |
|-----------|------|--------|-------------|
| Behavioral coverage | §1 row 1 reaches ≥ 90% of `expectedFromFixtures` rules verified live | TODO | Currently 18 compile + 56 fixture rules asserted; target ≥ 100 fixture rules |
| Fixture coverage | §1 row 2 reaches 100% (or 100% of non-exempt) | TODO | Currently **92.5%** (**1993**/**2154** category rule slots per `_rule_metrics`); exempt categories listed in `_FIXTURE_EXEMPT_CATEGORIES` |
| Quick-fix application proof | §10 D1-D5 land | TODO | Migration is structurally complete (§3); needs end-to-end verification |
| IDE integration sign-off | §5 / §10 E1-E5 land | TODO | Manual VS Code verification, recorded in `plans/history/` |
| Regression baseline | §10 F1 captured | TODO | v(N-1) vs current diff before tagging the release that closes this plan |

### Documentation

| Item | Status |
|------|--------|
| Active-line support policy in README | TODO (G2) |
| IDE-specific troubleshooting note | TODO (G3) — separate from existing README §Troubleshooting |
| CHANGELOG `[Unreleased]` records §3 quick-fix migration completion | TODO (G4) |

---

## 9. Remaining Integration Tests

Add each rule code to `expectedFromFixtures` in `test/fixture_lint_integration_test.dart` (~line 75), then run `dart test test/fixture_lint_integration_test.dart`. The suite now always asserts **18** compile-shape saropa codes from native `dart analyze` output; the longer list runs only when `dart run custom_lint` returns parseable violations (see `parseDartAnalyzeHumanOutput` in `lib/src/violation_parser.dart`).

### Metric + verify

- [x] Implement code_quality metric fix (§4.1) in `scripts/modules/_rule_metrics.py`
- [ ] Run `python scripts/publish.py` — confirm Fixtures 100%
- [ ] Run `dart test` — fix any failures

### api

- [ ] prefer_dio_over_http (`example_packages/lib/dio/prefer_dio_over_http_fixture.dart`)
- [ ] prefer_timeout_on_requests (`example/lib/api_network/prefer_timeout_on_requests_fixture.dart`)

### api_network

Batch 2026-04: first 25 rules below have a **fixture contract test** (`test/api_network_fixture_expect_lint_contract_test.dart`) asserting each `example/lib/api_network/*_fixture.dart` declares matching `expect_lint:` (not yet the full `fixture_lint_integration_test.dart` behavioral list).

- [x] avoid_cached_image_in_build
- [x] avoid_hardcoded_api_urls
- [x] avoid_over_fetching
- [x] avoid_redundant_requests
- [x] prefer_api_pagination
- [x] prefer_http_connection_reuse
- [x] prefer_streaming_response
- [x] require_analytics_event_naming
- [x] require_content_type_check
- [x] require_geolocator_timeout
- [x] require_http_status_check
- [x] require_image_picker_error_handling
- [x] require_image_picker_result_handling
- [x] require_image_picker_source_choice
- [x] require_notification_handler_top_level
- [x] require_notification_permission_android13
- [x] require_offline_indicator
- [x] require_permission_denied_handling
- [x] require_permission_rationale
- [x] require_permission_status_check
- [x] require_request_timeout
- [x] require_response_caching
- [x] require_retry_logic
- [x] require_sqflite_migration
- [x] require_typed_api_response
- [ ] require_url_launcher_error_handling
- [ ] require_websocket_error_handling

### async

- [ ] avoid_future_ignore
- [ ] avoid_future_in_build
- [ ] avoid_future_tostring
- [ ] avoid_multiple_stream_listeners
- [ ] avoid_nested_futures
- [ ] avoid_redundant_async
- [ ] avoid_sequential_awaits
- [ ] avoid_stream_sync_events
- [ ] avoid_stream_tostring
- [ ] avoid_sync_on_every_change
- [ ] prefer_assigning_await_expressions
- [ ] prefer_async_await
- [ ] prefer_async_callback
- [ ] prefer_async_init_state
- [ ] prefer_broadcast_stream
- [ ] prefer_commenting_future_delayed
- [ ] prefer_correct_future_return_type
- [ ] prefer_future_void_function_over_async_callback
- [ ] prefer_isolate_for_heavy_compute
- [ ] prefer_return_await
- [ ] prefer_stream_distinct
- [ ] prefer_utc_for_storage
- [ ] require_cache_ttl
- [ ] require_future_timeout
- [ ] require_location_timeout
- [ ] require_mounted_check_after_await
- [ ] require_network_status_check
- [ ] require_pending_changes_indicator
- [ ] require_stream_controller_dispose
- [ ] require_stream_error_handling
- [ ] require_stream_on_done
- [ ] require_websocket_message_validation
- [ ] require_websocket_reconnection
- [ ] use_setstate_synchronously

### bluetooth_hardware

- [ ] avoid_bluetooth_scan_without_timeout
- [ ] prefer_ble_mtu_negotiation
- [ ] require_audio_focus_handling
- [ ] require_ble_disconnect_handling
- [ ] require_geolocator_error_handling
- [ ] require_geolocator_permission_check
- [ ] require_geolocator_service_enabled
- [ ] require_geolocator_stream_cancel
- [ ] require_qr_permission_check

### config

- [ ] avoid_hardcoded_config_test
- [ ] avoid_platform_specific_imports
- [ ] avoid_string_env_parsing
- [ ] require_feature_flag_type_safety

### connectivity

- [ ] avoid_connectivity_equals_internet
- [ ] require_connectivity_error_handling

### context

- [ ] avoid_context_after_await_in_static
- [ ] avoid_context_dependency_in_callback
- [ ] avoid_context_in_async_static
- [ ] avoid_context_in_static_methods
- [ ] avoid_storing_context

### crypto

- [ ] avoid_deprecated_crypto_algorithms
- [ ] require_unique_iv_per_encryption

### debug

- [ ] avoid_debug_print
- [ ] avoid_print_in_production
- [ ] avoid_print_in_release
- [ ] avoid_sensitive_in_logs
- [ ] avoid_unguarded_debug
- [ ] prefer_commenting_analyzer_ignores
- [ ] prefer_debugPrint
- [ ] require_log_level_for_production
- [ ] require_structured_logging

### disposal

- [ ] avoid_hive_binary_storage
- [ ] avoid_hive_field_index_reuse
- [ ] avoid_shared_prefs_in_isolate
- [ ] avoid_sqflite_reserved_words
- [ ] avoid_websocket_memory_leak
- [ ] dispose_class_fields
- [ ] prefer_dispose_before_new_instance
- [ ] prefer_hive_lazy_box
- [ ] prefer_shared_prefs_async_api
- [ ] require_change_notifier_dispose
- [ ] require_debouncer_cancel
- [ ] require_file_handle_close
- [ ] require_interval_timer_cancel
- [ ] require_lifecycle_observer
- [ ] require_media_player_dispose
- [ ] require_page_controller_dispose
- [ ] require_receive_port_close
- [ ] require_shared_prefs_prefix
- [ ] require_socket_close
- [ ] require_sse_subscription_cancel
- [ ] require_tab_controller_dispose
- [ ] require_text_editing_controller_dispose
- [ ] require_video_player_controller_dispose

### error_handling

- [ ] avoid_catch_exception_alone
- [ ] avoid_generic_exceptions
- [ ] avoid_nested_try_statements
- [ ] avoid_print_error
- [ ] avoid_swallowing_exceptions
- [ ] prefer_result_pattern
- [ ] require_app_startup_error_handling
- [ ] require_async_error_documentation
- [ ] require_cache_key_determinism
- [ ] require_error_boundary
- [ ] require_error_context
- [ ] require_finally_cleanup
- [ ] require_notification_action_handling
- [ ] require_permission_permanent_denial_handling

### file_handling

- [ ] avoid_loading_full_pdf_in_memory
- [ ] prefer_sqflite_batch
- [ ] prefer_sqflite_column_constants
- [ ] prefer_sqflite_singleton
- [ ] prefer_streaming_for_large_files
- [ ] require_file_exists_check
- [ ] require_file_path_sanitization
- [ ] require_graphql_error_handling
- [ ] require_pdf_error_handling
- [ ] require_sqflite_error_handling
- [ ] require_sqflite_transaction
- [ ] require_sqflite_whereargs

### iap

- [ ] avoid_entitlement_without_server
- [ ] avoid_purchase_in_sandbox_production
- [ ] require_price_localization
- [ ] require_subscription_status_check

### json

- [ ] avoid_datetime_parse_unvalidated
- [ ] avoid_double_for_money
- [ ] avoid_hardcoded_config
- [ ] avoid_mixed_environments
- [ ] avoid_optional_field_crash
- [ ] avoid_sensitive_in_logs
- [ ] prefer_explicit_json_keys
- [ ] prefer_iso8601_dates
- [ ] prefer_try_parse_for_dynamic_data
- [ ] require_date_format_specification
- [ ] require_json_decode_try_catch

### json_datetime

- [ ] avoid_datetime_now_in_tests
- [ ] prefer_duration_constants
- [ ] prefer_json_serializable
- [ ] require_json_schema_validation
- [ ] require_timezone_display

### lifecycle

- [ ] avoid_work_in_paused_state
- [ ] require_app_lifecycle_handling
- [ ] require_did_update_widget_check
- [ ] require_late_initialization_in_init_state
- [ ] require_resume_state_refresh
- [ ] require_widgets_binding_callback

### media

- [ ] avoid_autoplay_audio
- [ ] prefer_audio_session_config
- [ ] prefer_camera_resolution_selection

### memory

- [ ] avoid_unbounded_cache_growth

### memory_management

- [ ] avoid_capturing_this_in_callbacks
- [ ] avoid_expando_circular_references
- [ ] avoid_large_isolate_communication
- [ ] avoid_large_objects_in_state
- [ ] avoid_retaining_disposed_widgets
- [ ] prefer_weak_references_for_cache
- [ ] require_cache_eviction_policy
- [ ] require_cache_expiration
- [ ] require_cache_key_uniqueness
- [ ] require_image_disposal

### money

- [ ] require_currency_code_with_amount

### notification

- [ ] avoid_notification_payload_sensitive
- [ ] avoid_notification_same_id
- [ ] avoid_notification_silent_failure
- [ ] prefer_notification_grouping
- [ ] require_notification_channel_android
- [ ] require_notification_timezone_awareness

### performance

- [ ] avoid_animation_in_large_list
- [ ] avoid_blocking_main_thread
- [ ] avoid_calling_of_in_build
- [ ] avoid_closure_memory_leak
- [ ] avoid_excessive_widget_depth
- [ ] avoid_expensive_computation_in_build
- [ ] avoid_finalizer_misuse
- [ ] avoid_json_in_main
- [ ] avoid_large_list_copy
- [ ] avoid_memory_intensive_operations
- [ ] avoid_money_arithmetic_on_double
- [ ] avoid_setstate_in_build
- [ ] avoid_text_span_in_build
- [ ] prefer_cached_getter
- [ ] prefer_compute_for_heavy_work
- [ ] prefer_disk_cache_for_persistence
- [ ] prefer_element_rebuild
- [ ] prefer_image_precache
- [ ] prefer_inherited_widget_cache
- [ ] prefer_static_const_widgets
- [ ] prefer_value_listenable_builder
- [ ] require_dispose_pattern
- [ ] require_image_cache_management
- [ ] require_isolate_for_heavy
- [ ] require_keys_in_animated_lists
- [ ] require_menu_bar_for_desktop
- [ ] require_repaint_boundary
- [ ] require_widget_key_strategy
- [ ] require_window_close_confirmation

### permission

- [ ] avoid_permission_handler_null_safety
- [ ] avoid_permission_request_loop
- [ ] prefer_image_cropping
- [ ] require_camera_permission_check
- [ ] require_location_permission_rationale

### resource_management

- [ ] avoid_image_picker_without_source
- [ ] prefer_coarse_location_when_sufficient
- [ ] prefer_geolocator_accuracy_appropriate
- [ ] require_camera_dispose
- [ ] require_database_close
- [ ] require_file_close_in_finally
- [ ] require_http_client_close
- [ ] require_image_compression
- [ ] require_isolate_kill
- [ ] require_platform_channel_cleanup
- [ ] require_websocket_close

### security

- [ ] avoid_api_key_in_code
- [ ] avoid_auth_in_query_params
- [ ] avoid_clipboard_sensitive
- [ ] avoid_dynamic_code_loading
- [ ] avoid_dynamic_sql
- [ ] avoid_encryption_key_in_memory
- [ ] avoid_eval_like_patterns
- [ ] avoid_external_storage_sensitive
- [ ] avoid_generic_key_in_url
- [ ] avoid_hardcoded_credentials
- [ ] avoid_hardcoded_signing_config
- [ ] avoid_ignoring_ssl_errors
- [ ] avoid_jwt_decode_client
- [ ] avoid_logging_sensitive_data
- [ ] avoid_path_traversal
- [ ] avoid_redirect_injection
- [ ] avoid_screenshot_sensitive
- [ ] avoid_secure_storage_large_data
- [ ] avoid_sensitive_data_in_clipboard
- [ ] avoid_stack_trace_in_production
- [ ] avoid_storing_passwords
- [ ] avoid_storing_sensitive_unencrypted
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
- [ ] prefer_local_auth
- [ ] prefer_secure_random
- [ ] prefer_typed_data
- [ ] prefer_webview_javascript_disabled
- [ ] require_auth_check
- [ ] require_biometric_fallback
- [ ] require_catch_logging
- [ ] require_certificate_pinning
- [ ] require_clipboard_paste_validation
- [ ] require_data_encryption
- [ ] require_deep_link_validation
- [ ] require_https_only
- [ ] require_https_only_test
- [ ] require_input_sanitization
- [ ] require_logout_cleanup
- [ ] require_secure_password_field
- [ ] require_secure_storage
- [ ] require_secure_storage_auth_data
- [ ] require_secure_storage_error_handling
- [ ] require_secure_storage_for_auth
- [ ] require_token_refresh
- [ ] require_url_validation
- [ ] require_webview_error_handling

### state_management

- [ ] avoid_getx_global_state
- [ ] avoid_getx_static_context
- [ ] avoid_global_key_in_build
- [ ] avoid_large_bloc
- [ ] avoid_riverpod_for_network_only
- [ ] avoid_setstate_in_large_state_class
- [ ] avoid_stateful_without_state
- [ ] avoid_static_state
- [ ] prefer_bloc_transform
- [ ] prefer_change_notifier_proxy
- [ ] prefer_change_notifier_proxy_provider
- [ ] prefer_immutable_selector_value
- [ ] prefer_selector_widget
- [ ] require_bloc_event_sealed
- [ ] require_bloc_repository_abstraction
- [ ] require_mounted_check
- [ ] require_notify_listeners
- [ ] require_value_notifier_dispose

---

## Policy: No Stub Fixtures

A fixture file must not be added until the rule is implemented and validated. Counting stub files as "fixtures" is prohibited. See CONTRIBUTING.md for details.

---

## 10. 50 Atomic Implementation Items

Each item below is **independently completable**: one fixture / one assertion / one verification. Acceptance criteria stated inline. Group prefix (A/B/C…) indicates theme, not ordering — pick any.

### A. Plan accuracy follow-ups (3)

1. **A1.** Re-run `python scripts/publish.py` (audit-only or analyze-only) once the British-spelling prompt is acknowledged, capture the new "Fixtures" percentage, and update §1 if it has moved off 92.4%.
2. **A2.** Verify §9 `expectedFromFixtures` rule count matches `test/fixture_lint_integration_test.dart` line 134-191 (currently 56, not 58 as the old §1 claim said). Update if the test list has changed since.
3. **A3.** ~~Reconcile the 2154 vs 2158 rule-count discrepancy~~ **Done 2026-05-01.** Both numbers are correct and measure different things:
   - **2154** = rule **classes** (`class X extends SaropaLintRule | DartLintRule`) — the canonical rule count.
   - **2158** = unique **`LintCode` names** — each name is a separately-fixable diagnostic.
   - The +4 delta comes from rules that define multiple codes:
     - `lib/src/rules/stylistic/stylistic_rules.dart`: 45 classes / 47 codes (+2)
     - `lib/src/rules/config/dart_sdk_3_removal_rules.dart`: 15 classes / 16 codes (+1)
     - `lib/src/rules/config/dart_sdk_34_deprecation_rules.dart`: 0 classes / 1 code (+1; free-standing `LintCode` constant, no rule class)
   - Use **2154** for headline "rule class" count (README, CHANGELOG); use **2158** for unique `LintCode` names. The **fixture percentage** in publish output uses the **sum of per-category rule slots** (also **2154** here) as its denominator — not 2158.

### B. Repair the 3 disabled fixtures (3)

Each is currently gated by `// HACK: TODO restore when available to testing`. Acceptance: remove the HACK comment, fixture compiles in its example package, fixture's BAD case still fires the lint when run via `dart run custom_lint`.

4. **B1.** `example/lib/code_quality/prefer_redirecting_superclass_constructor_fixture.dart:118:24` — fix `super_formal_parameter_without_associated_positional` (declare matching positional param on the superclass, or rewrite the redirect).
5. **B2.** `example_packages/lib/packages/avoid_bloc_event_mutation_fixture.dart:125:9` — fix `const_constructor_with_non_const_super` (drop `const`, or make the super constructor `const`).
6. **B3.** `example_packages/lib/packages/require_bloc_initial_state_fixture.dart:111:3` — fix `implicit_super_initializer_missing_arguments` (add explicit super initializer with required args).

### C. Promote existing fixtures into behavioral assertions (24)

Each item: add the rule code to `expectedFromFixtures` in [test/fixture_lint_integration_test.dart](../test/fixture_lint_integration_test.dart) (~line 134), then run `dart test test/fixture_lint_integration_test.dart` and confirm the assertion passes when `dart run custom_lint` is available. Each rule listed below already has a fixture file in `example/lib/<category>/` (verified 2026-04-30).

7.  **C1.** `avoid_future_ignore` — fixture: `example/lib/async/avoid_future_ignore_fixture.dart`.
8.  **C2.** `avoid_future_in_build` — fixture: `example/lib/async/avoid_future_in_build_fixture.dart`.
9.  **C3.** `avoid_future_tostring` — fixture: `example/lib/async/avoid_future_tostring_fixture.dart`.
10. **C4.** `avoid_multiple_stream_listeners` — fixture: `example/lib/async/avoid_multiple_stream_listeners_fixture.dart`.
11. **C5.** `avoid_nested_futures` — fixture: `example/lib/async/avoid_nested_futures_fixture.dart`.
12. **C6.** `avoid_redundant_async` — fixture: `example/lib/async/avoid_redundant_async_fixture.dart`.
13. **C7.** `avoid_sequential_awaits` — fixture: `example/lib/async/avoid_sequential_awaits_fixture.dart`.
14. **C8.** `avoid_stream_sync_events` — fixture: `example/lib/async/avoid_stream_sync_events_fixture.dart`.
15. **C9.** `avoid_stream_tostring` — fixture: `example/lib/async/avoid_stream_tostring_fixture.dart`.
16. **C10.** `avoid_sync_on_every_change` — fixture: `example/lib/async/avoid_sync_on_every_change_fixture.dart`.
17. **C11.** `dispose_class_fields` — fixture: `example/lib/disposal/dispose_class_fields_fixture.dart`.
18. **C12.** `prefer_dispose_before_new_instance` — fixture: `example/lib/disposal/prefer_dispose_before_new_instance_fixture.dart`.
19. **C13.** `require_change_notifier_dispose` — fixture: `example/lib/disposal/require_change_notifier_dispose_fixture.dart`.
20. **C14.** `require_text_editing_controller_dispose` — fixture: `example/lib/disposal/require_text_editing_controller_dispose_fixture.dart`.
21. **C15.** `require_video_player_controller_dispose` — fixture: `example/lib/disposal/require_video_player_controller_dispose_fixture.dart`.
22. **C16.** `avoid_swallowing_exceptions` — fixture: `example/lib/error_handling/avoid_swallowing_exceptions_fixture.dart`.
23. **C17.** `avoid_generic_exceptions` — fixture: `example/lib/error_handling/avoid_generic_exceptions_fixture.dart`.
24. **C18.** `prefer_result_pattern` — fixture: `example/lib/error_handling/prefer_result_pattern_fixture.dart`.
25. **C19.** `require_app_startup_error_handling` — fixture: `example/lib/error_handling/require_app_startup_error_handling_fixture.dart`.
26. **C20.** `avoid_hardcoded_credentials` — fixture: `example/lib/security/avoid_hardcoded_credentials_fixture.dart`.
27. **C21.** `avoid_token_in_url` — fixture: `example/lib/security/avoid_token_in_url_fixture.dart`.
28. **C22.** `avoid_path_traversal` — fixture: `example/lib/security/avoid_path_traversal_fixture.dart`.
29. **C23.** `avoid_jwt_decode_client` — fixture: `example/lib/security/avoid_jwt_decode_client_fixture.dart`.
30. **C24.** `prefer_local_auth` — fixture: `example/lib/security/prefer_local_auth_fixture.dart`.

### D. Quick-fix application end-to-end (5)

There is no current Dart test that takes a `SaropaFixProducer`, applies it to a fixture, and asserts the resulting source. These five build that surface so the migration claim in §3 is *provable*, not just structurally complete.

31. **D1.** Add `test/fix_application_smoke_test.dart` — pick one rule with a one-line replacement fix (suggest `replace_with_https_fix.dart`), invoke its `SaropaFixProducer.run` against a synthetic source, assert the rewritten source equals an expected string. No I/O dependence.
32. **D2.** Extend D1 with a delete-node case (suggest `delete_node_fix.dart` via a real consumer rule).
33. **D3.** Extend D1 with an insert-node case (suggest `insert_text_fix.dart` via a real consumer rule).
34. **D4.** Add an integration test that runs `dart fix --apply` (or `--dry-run`) inside the `example/` package over a single curated fixture file, captures the diff, and asserts the expected lines change. Skip when binary unavailable, like the existing custom_lint tests.
35. **D5.** Document in `CONTRIBUTING.md` § "Adding a quick fix" the minimum unit-test contract that D1-D3 enforce, so new fix producers cannot land without an application test.

### E. IDE integration verification (5)

> **Status 2026-05-01:** verification record template scaffolded at [`plans/history/2026.05/2026.05.01/ide_integration/README.md`](history/2026.05/2026.05.01/ide_integration/README.md) — complete with prerequisites, per-step expected behavior, failure triage, and a results table. The interactive PASS/FAIL filling requires a human at a VS Code session (cannot be run headless).

36. **E1.** Open `example/lib/security/avoid_hardcoded_credentials_fixture.dart` in VS Code with the saropa_lints plugin active; confirm a red squiggle appears on the BAD line and the rule code shows in the Problems panel. **(Scaffolded; awaiting manual verification.)**
37. **E2.** Hover the BAD line in E1; confirm the lightbulb appears and the menu lists the saropa fix. **(Scaffolded; awaiting manual verification.)**
38. **E3.** Apply the lightbulb fix from E2; confirm the source rewrite matches the producer's intended replacement and the diagnostic clears. **(Scaffolded; awaiting manual verification.)**
39. **E4.** From the integrated terminal, run `dart analyze` in `example/`; confirm at least one `saropa_lints` rule code appears in the output. **(Scaffolded; awaiting manual verification.)**
40. **E5.** From the integrated terminal, run `dart fix --apply` in `example/` against a copy of one fixture; confirm the BAD case is rewritten and `dart analyze` no longer flags that line. **(Scaffolded; awaiting manual verification.)**

### F. Regression and performance baselines (5)

> **Status 2026-05-01:** F1-F4 captured against v12.8.4 — see [`plans/history/2026.05/2026.05.01/perf/perf_baseline.md`](history/2026.05/2026.05.01/perf/perf_baseline.md). F5 folded into the IDE manual checklist (E1).

41. **F1.** ~~v4 vs v5 violation diff~~ Reframed for the active 12.x line: captured `dart analyze --format=machine` output for both example packages at v12.8.4 as the regression baseline. Diff against the next tag is mechanical (recipe in the perf doc). **Done.**
42. **F2.** Three warm runs of `dart analyze` over `example/`: 5042 / 5416 / 8418 ms (min/median/max 5042 / 5416 / 8418). **Done.**
43. **F3.** Three warm runs of `dart analyze` over `example_packages/`: 3048 / 3099 / 3439 ms. **Done.**
44. **F4.** Peak RSS via PowerShell `WorkingSet64` polling: 8.3 MB on the launcher process; full analyzer-tree capture is a follow-up (caveat noted in the perf doc). **Done with caveat.**
45. **F5.** ~~Time-to-squiggle in VS Code~~ Folded into the IDE manual checklist E1 — no separate automated capture (would need WebDriver). **Folded into E.**

### G. Release-prep documentation (5)

> Reframed 2026-05-01: the project is on v12.x; the native-plugin migration shipped within the 12.x line (commit `f51191b6`, 2026-02-16). The original "v4 deprecation / v5 stable" framing was inherited from a stale source plan and does not match `pubspec.yaml: version: 12.8.4`. Items below now target the active line.

46. **G1.** Update plan `§8 Release Plan` to drop the fictional `5.0.0-beta.2` / `5.0.0` rows and replace with quality-gate milestones against the active 12.x series. (Done as part of this revision; verify the file reflects the change.)
47. **G2.** Add a one-paragraph "Supported versions" note to `README.md` immediately after the badge block (or before §Troubleshooting): which minor lines receive new rules vs. security-only patches, and how to request a backport. Keep it short — under 6 lines.
48. **G3.** Add `doc/troubleshooting.md` (project convention is `doc/`, not `docs/`) covering the three most common IDE-specific reports: (1) custom_lint not running, (2) saropa rules not appearing in Problems panel, (3) quick fix not showing in lightbulb. One diagnostic command and one fix per item. Link to it from README §Troubleshooting (which already exists at line 1027 and is broader).
49. **G4.** Update `CHANGELOG.md` `[Unreleased]` `<details>Maintenance</details>` block with the §3 status correction (quick-fix migration recorded as complete; 0 `extends DartFix` left in `lib/`). Per memory `feedback_changelog_maintenance.md`, this is internal hygiene and goes in the maintenance expander, not Added/Changed/Fixed.
50. **G5.** Add a release-readiness checklist to plan `§8` linking the gating items (B1-B3, D1-D5, E1-E5, F1) so the next release-class commit can be evaluated against a single page. (Done as part of this revision via the new milestone table; verify and adjust if §10 item IDs renumber.)

---

### Verification commands used to fact-check this plan (2026-04-30)

```text
Grep "extends DartFix"        in lib/   → 0 matches
Grep "extends SaropaFixProducer" in lib/ → 221 files / 249 occurrences
Grep "// HACK: TODO restore"  in example*/lib → 3 files (matches §2)
fixture coverage from _count_fixtures_for_category → 1993/2154 = 92.5% (2026-05-08)
expectedCompileTimeFromDartAnalyze: 18 entries (lines 109-128)
expectedFromFixtures:               56 entries (lines 134-190)
```

---

## References

- Integration test: `test/fixture_lint_integration_test.dart`
- Metrics script: `scripts/modules/_rule_metrics.py`
- Completed batch history: `bugs/history/unit_test_coverage_fixtures_and_instantiation_completed.md`, `bugs/history/unit_test_coverage_batch_2026-03-03.md`
- Quick-fix coverage gaps (separate from migration): `plans/QUICK_FIX_PLAN.md`

---

_Created: 2026-03-14_
