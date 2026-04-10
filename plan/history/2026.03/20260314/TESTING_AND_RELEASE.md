# Testing & Release Plan

Consolidated from TESTING_ISSUES.md, task-phase6-testing-release.md, and UNIT_TEST_COVERAGE.md.

**Last updated:** 2026-03-14
**Scope:** All lint rules in `lib/src/rules/`, tests in `test/`, and v5 release readiness.
**Goal:** Fixtures = 100%, all quick fixes migrated, IDE integration verified.

---

## 1. Current Status

| Item | Status | Notes |
|------|--------|-------|
| Fixtures (per-rule, 27 reviewed categories) | **Done** | 0 missing in those 27 categories |
| Rule instantiation tests (108 categories) | **Done** | All have "Rule Instantiation" group |
| Behavioral tests (linter on code) | **In progress** | `fixture_lint_integration_test.dart`; 56 rules covered |
| Publish report "Fixtures" metric | **<100%** | ~96.3% (1971/2047) due to metrics bug |
| Quick fix migration (native plugin) | **1%** | 2 of 213 fixes migrated |
| IDE integration testing | **Not started** | |

---

## 2. Disabled Tests

These fixture files have compile errors and are temporarily disabled:

```dart
// HACK: TODO restore when available to testing
```

| Error | File | Issue |
|-------|------|-------|
| No associated positional super constructor parameter | `example_core/lib/code_quality/prefer_redirecting_superclass_constructor_fixture.dart:118:24` | `super_formal_parameter_without_associated_positional` |
| Constant constructor can't call non-constant super constructor | `example_packages/lib/packages/avoid_bloc_event_mutation_fixture.dart:125:9` | `const_constructor_with_non_const_super` |
| Implicitly invoked unnamed constructor has required parameters | `example_packages/lib/packages/require_bloc_initial_state_fixture.dart:111:3` | `implicit_super_initializer_missing_arguments` |

---

## 3. Quick Fix Migration (CRITICAL)

Primary motivation for the native plugin migration — only 2 of 213 fixes migrated (1%).

| Status | Fix | Rule File |
|--------|-----|-----------|
| Done | `CommentOutDebugPrintFix` | `debug_rules.dart` |
| Done | `RemoveEmptySetStateFix` | `widget_lifecycle_rules.dart` |
| TODO | **211 remaining fixes** | Various `*_rules.dart` files |

**Pattern**: Migrate each `DartFix` subclass to `SaropaFixProducer`, then add to the rule's `fixGenerators` getter.

---

## 4. Publish Report Fixtures < 100%

### 4.1 code_quality metric bug (NOT DONE)

**File:** `scripts/modules/_rule_metrics.py`
**Function:** `_count_fixtures_for_category` (~line 190)

Four categories (`code_quality_avoid`, `code_quality_control_flow`, `code_quality_prefer`, `code_quality_variables`) share one fixture dir: `example_core/lib/code_quality/` (108 `*_fixture.dart` files). The function must resolve to `example_core` and use each category's own `rule_names` to count correctly.

**Fix:** At the start of `_count_fixtures_for_category`, add a branch:
- If `category.startswith("code_quality_")`: resolve fixture dir to `example_core/lib/code_quality/` only
- List `*_fixture.dart`, compute basenames, return `len(basenames.intersection(rule_names))`
- Do not use the same count for all four categories

### 4.2 Isar commented-out rule (DONE)

`_strip_line_comments` in `_rule_metrics.py` is applied before `_RULE_CLASS_RE`, so commented-out classes are excluded.

### 4.3 Missing fixture files

All fixtures listed in §8 have been verified to exist as of 2026-03-06. Any remaining gap is from the code_quality metric bug (§4.1).

---

## 5. Fixture Coverage — 27 Categories Complete

| Category | Rules | Fixtures | Missing |
|----------|------:|--------:|--------:|
| structure | 45 | 45 | 0 |
| class_constructor | 20 | 20 | 0 |
| naming_style | 28 | 28 | 0 |
| type | 18 | 18 | 0 |
| control_flow | 31 | 31 | 0 |
| hive | 23 | 23 | 0 |
| performance | 49 | 49 | 0 |
| widget_patterns | 104 | 104 | 0 |
| api_network | 38 | 38 | 0 |
| code_quality | 105 | 108 | 0 |
| collection | 25 | 25 | 0 |
| complexity | 14 | 14 | 0 |
| firebase | 29 | 29 | 0 |
| memory_management | 13 | 13 | 0 |
| return | 7 | 7 | 0 |
| stylistic_additional | 24 | 24 | 0 |
| web | 8 | 8 | 0 |
| animation | 19 | 19 | 0 |
| config | 7 | 7 | 0 |
| connectivity | 3 | 3 | 0 |
| freezed | 10 | 10 | 0 |
| isar | 21 | 21 | 0 |
| notification | 8 | 8 | 0 |
| sqflite | 2 | 2 | 0 |
| type_safety | 17 | 17 | 0 |
| ui_ux | 20 | 20 | 0 |
| widget_lifecycle | 36 | 36 | 0 |

---

## 6. IDE Integration Testing

| Test | Status | Notes |
|------|--------|-------|
| VS Code squiggles appear | TODO | Verify diagnostics show inline |
| Problems panel populated | TODO | Verify rule violations listed |
| Quick fixes appear (lightbulb) | TODO | **Primary motivation** — verify fixes show in VS Code |
| Quick fixes apply correctly | TODO | Verify applied fix produces correct code |
| `dart analyze` integration | TODO | Verify rules run via CLI |
| `dart fix --apply` integration | TODO | Verify bulk fix application |

---

## 7. Regression & Performance Testing

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

## 8. Fixture Paths Reference

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

## 9. Release Plan

| Milestone | Version | Status | Description |
|-----------|---------|--------|-------------|
| Dev | `5.0.0-dev.1` | Done | Infrastructure + PoC |
| Beta 1 | `5.0.0-beta.1` | Done | All rules migrated, 2 quick fixes |
| Beta 2 | `5.0.0-beta.2` | TODO | All quick fixes migrated, reporter features verified |
| Stable | `5.0.0` | TODO | After beta feedback |

### Documentation

| Item | Status |
|------|--------|
| Migration guide (`MIGRATION_V5.md`) | Done |
| v4 deprecation notice | TODO |
| v4 security fix maintenance policy | TODO |
| Troubleshooting guide | TODO |

---

## 10. Remaining Integration Tests

Add each rule code to `expectedFromFixtures` in `test/fixture_lint_integration_test.dart` (~line 75), then run `dart test test/fixture_lint_integration_test.dart`. 56 rules are already in the list.

### Metric + verify

- [ ] Implement code_quality metric fix (§4.1) in `scripts/modules/_rule_metrics.py`
- [ ] Run `python scripts/publish.py` — confirm Fixtures 100%
- [ ] Run `dart test` — fix any failures

### api (`example_async/lib/api/`)

- [ ] prefer_dio_over_http
- [ ] prefer_timeout_on_requests

### api_network

- [ ] avoid_cached_image_in_build
- [ ] avoid_hardcoded_api_urls
- [ ] avoid_over_fetching
- [ ] avoid_redundant_requests
- [ ] prefer_api_pagination
- [ ] prefer_http_connection_reuse
- [ ] prefer_streaming_response
- [ ] require_analytics_event_naming
- [ ] require_content_type_check
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
- [ ] require_typed_api_response
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

## References

- Integration test: `test/fixture_lint_integration_test.dart`
- Metrics script: `scripts/modules/_rule_metrics.py`
- Completed batch history: `bugs/history/unit_test_coverage_fixtures_and_instantiation_completed.md`, `bugs/history/unit_test_coverage_batch_2026-03-03.md`

---

_Created: 2026-03-14_
