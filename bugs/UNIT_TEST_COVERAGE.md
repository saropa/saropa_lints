# Unit Test Coverage: Status and Plan to 100%

**Last updated:** 2026-03-03  
**Scope:** All lint rules in `lib/src/rules/` and all rule-related tests in `test/`.  
**Goal:** Publish “Test Coverage” report shows **Fixtures = 100%**.

---

## Remaining work (what to do next)

Only the following is still open. Everything else in this doc is either done or reference.

### 1. Metric fix: code_quality fixture count (required for report to reach 100%)

**File:** `scripts/modules/_rule_metrics.py`  
**Function:** `_count_fixtures_for_category(example_dirs, category, *, rule_names=None)` (starts ~line 190).

**Current behaviour:** The function uses `_fixture_category_alias(category)` so that `code_quality_avoid`, `code_quality_control_flow`, `code_quality_prefer`, `code_quality_variables` all map to `fixture_category = "code_quality"`. It then looks for a directory `lib_dir / suffix` with `suffix` in `["code_quality", "code_qualitys"]` in **any** of `example_dirs`. If found, it lists `*_fixture.dart` and, when `rule_names` is provided, returns `len(basenames.intersection(rule_names))`. The call site in `display_test_coverage` (line ~339) already passes `rule_names=cat.rule_names` from `_collect_category_rules`. So in theory each code_quality_* category should get a count equal to how many of **that file’s** rule names have a matching fixture in the shared dir.

**Why the report can still show 0 for code_quality_*:** The directory that actually contains the 104 fixtures is **only** `example_core/lib/code_quality/`. If the loop over `example_dirs` and `suffix` hits another example package first (e.g. `example/lib/code_quality` if it exists) and that path exists but has no fixtures or different layout, the count can be wrong or 0. So the fix must **explicitly** resolve code_quality to `example_core`’s lib dir.

**Concrete change:** At the start of `_count_fixtures_for_category`, add a branch:

- If `category.startswith("code_quality_")`:
  - Resolve fixture dir to the **code_quality** directory under **example_core** only. For example: from `example_dirs` find the `lib_dir` whose parent is named `example_core` (e.g. `next((d for d in example_dirs if d.parent.name == "example_core"), None)`), then `fixture_dir = lib_dir / "code_quality"`.
  - If `fixture_dir.exists()`: list `fixture_dir.glob("*_fixture.dart")`, compute `basenames = {f.stem.replace("_fixture", "") for f in fixtures}`, and return `len(basenames.intersection(rule_names))` when `rule_names` is not None, else `len(fixtures)`.
  - If not exists, return 0.
  - Do **not** use the same count for all four categories: each category must use its own `rule_names` (already passed in) so that code_quality_avoid gets only avoid-rule fixtures, etc.

**Rule names source:** `rule_names` come from `_collect_category_rules`, which reads each `lib/src/rules/**/*_rules.dart` and extracts the first string literal from each `LintCode(...)` via `_LINT_NAME_RE`. So code_quality_avoid_rules.dart → one set of names, code_quality_control_flow_rules.dart → another, etc. No change needed there.

**Categories affected:** `code_quality_avoid`, `code_quality_control_flow`, `code_quality_prefer`, `code_quality_variables`. Rule files: `lib/src/rules/code_quality/code_quality_avoid_rules.dart` (and same path with `_control_flow`, `_prefer`, `_variables`). Fixture dir: `example_core/lib/code_quality/` (104 `*_fixture.dart` files).

### 2. Isar metric (already done)

Comment stripping in `_rule_metrics.py` (`_strip_line_comments` before `_RULE_CLASS_RE`) ensures commented-out rule classes in `lib/src/rules/packages/isar_rules.dart` are not counted. No action.

### 3. Real missing fixtures (check §6.3 table)

For each row in the **§6.3** table, the “Directory” column is the exact directory; the fixture file must be `{Directory}/{rule_name}_fixture.dart`. Rules can have multiple rule names (e.g. config has two). **Check that each of these files exists** (no stubs):

| Rule name(s) | Full fixture path(s) |
|--------------|----------------------|
| `avoid_void_async` | `example_async/lib/async/avoid_void_async_fixture.dart` |
| `prefer_final_fields_always` | `example_core/lib/class_constructor/prefer_final_fields_always_fixture.dart` |
| `prefer_compile_time_config`, `prefer_flavor_configuration` | `example_async/lib/config/prefer_compile_time_config_fixture.dart`, `example_async/lib/config/prefer_flavor_configuration_fixture.dart` |
| `prefer_connectivity_debounce` | `example_async/lib/connectivity/prefer_connectivity_debounce_fixture.dart` |
| `prefer_freezed_union_types` | `example_packages/lib/freezed/prefer_freezed_union_types_fixture.dart` |
| `prefer_correct_json_casts` | `example_async/lib/json_datetime/prefer_correct_json_casts_fixture.dart` |
| `prefer_go_router_builder` | `example_widgets/lib/navigation/prefer_go_router_builder_fixture.dart` |
| `prefer_auto_route_path_params_simple`, `prefer_auto_route_typed_args` | `example_packages/lib/auto_route/prefer_auto_route_path_params_simple_fixture.dart`, `prefer_auto_route_typed_args_fixture.dart` |
| `avoid_cubit_usage` | `example_packages/lib/bloc/avoid_cubit_usage_fixture.dart` |
| `prefer_firebase_transaction_for_counters`, `prefer_correct_topics`, `prefer_deep_link_auth` | `example_packages/lib/firebase/prefer_firebase_transaction_for_counters_fixture.dart`, `prefer_correct_topics_fixture.dart`, `prefer_deep_link_auth_fixture.dart` |
| `prefer_geolocation_coarse_location` | `example_packages/lib/geolocator/prefer_geolocation_coarse_location_fixture.dart` |
| `avoid_getx_rx_nested_obs` | `example_packages/lib/getx/avoid_getx_rx_nested_obs_fixture.dart` |
| `avoid_riverpod_string_provider_name` | `example_packages/lib/riverpod/avoid_riverpod_string_provider_name_fixture.dart` |
| `prefer_disk_cache_for_persistence` | `example_async/lib/performance/prefer_disk_cache_for_persistence_fixture.dart` |
| `prefer_class_destructuring` | `example_core/lib/record_pattern/prefer_class_destructuring_fixture.dart` |
| `avoid_returning_this` | `example_core/lib/return/avoid_returning_this_fixture.dart` |
| `prefer_expression_body_getters`, `prefer_block_body_setters` | `example_style/lib/stylistic/prefer_expression_body_getters_fixture.dart`, `prefer_block_body_setters_fixture.dart` |
| `prefer_dark_mode_colors`, `prefer_high_contrast_mode` | `example_widgets/lib/theming/prefer_dark_mode_colors_fixture.dart`, `prefer_high_contrast_mode_fixture.dart` |
| `prefer_flex_for_complex_layout`, `prefer_find_child_index_callback` | `example_widgets/lib/widget_layout/prefer_flex_for_complex_layout_fixture.dart`, `prefer_find_child_index_callback_fixture.dart` |
| `avoid_bool_in_widget_constructors`, `avoid_unnecessary_containers`, `prefer_const_literals_to_create_immutables` | `example_widgets/lib/widget_patterns/avoid_bool_in_widget_constructors_fixture.dart`, `avoid_unnecessary_containers_fixture.dart`, `prefer_const_literals_to_create_immutables_fixture.dart` |

If a file is missing: add it (one BAD example with `// expect_lint: rule_name` that the rule reports on, one GOOD example). No stubs: the rule must be implemented and the BAD example must trigger the linter. Validate with `dart run custom_lint` in the corresponding example package. **Do not** add a fixture for `prefer_builder_pattern` (architecture): rule not implemented (empty run).

### 4. Verify

- Run: `python scripts/publish.py` (or the same command your CI uses). In the “Test Coverage” section, confirm **Fixtures** line shows 100% (or 1990/1990).
- Run: `dart test`. Fix any failing tests.

### 5. Behavioral tests (optional)

In `test/fixture_lint_integration_test.dart`, the list `expectedFromFixtures` (around line 75) is used to assert that when `custom_lint` runs on `example_async`, those rule codes appear in the parsed violations. To add more: pick rule codes that have a fixture under `example_async/lib/` with `// expect_lint: <code>`, append the code to the list, run `dart test test/fixture_lint_integration_test.dart` to confirm the test passes.

---

## Policy: No stub fixtures

**Stub fixtures are prohibited.** A fixture file must not be added for a rule until that rule is implemented and the fixture is validated.

- **Do not** add a fixture that only contains `// expect_lint: rule_name` and placeholder BAD/GOOD code when the rule’s `runWithReporter()` is empty or does not report on that code. That is a stub and inflates coverage without testing anything.
- **Do** add a fixture only when the rule actually runs and reports on the BAD example (so that `expect_lint` would fail if the rule regressed). The fixture must be validated (e.g. by running the linter on the example package or by an integration test that asserts the expected lint appears).
- **If a rule is not yet implemented:** do not create a fixture for it. Fix the metrics (§6.1–6.2) and/or implement the rule first; then add the fixture and validate it.

Counting stub files as “fixtures” is not allowed.

---

## 1. Current status at a glance

| Item | Status | Notes |
|------|--------|--------|
| Fixtures (one per rule in reviewed categories) | **Done for 27 categories** | Those 27 have 0 missing. Other rules still need fixtures — see §6.3. |
| Rule instantiation tests (one per rule, metadata assertions) | **Done for 99 categories** | All category test files have a Rule Instantiation group. See §3. |
| Real behavioral tests (linter on code, assert lint present/absent) | **In progress** | Violating→lint and compliant→no lint in `fixture_lint_integration_test.dart`. See §5. |
| Publish report “Fixtures” metric | **&lt;100%** | ~98.3% due to metrics bugs and a few real gaps. See §4 and §6. |

---

## 2. Fixtures — 27 categories complete (others have gaps)

All 27 categories below have **0 rules without a dedicated fixture**. Other categories/rules still have missing fixtures; see §6.3 for the list to add.

| Category              | Rule count | Fixture count | Missing |
|-----------------------|-----------:|--------------:|--------:|
| structure             | 45         | 45            | 0       |
| class_constructor     | 20         | 20            | 0       |
| naming_style          | 28         | 28            | 0       |
| type                  | 18         | 18            | 0       |
| control_flow          | 31         | 31            | 0       |
| hive                  | 23         | 23            | 0       |
| performance           | 49         | 49            | 0       |
| widget_patterns       | 104        | 104           | 0       |
| api_network           | 38         | 38            | 0       |
| code_quality          | 105        | 104+          | 0       |
| collection            | 25         | 25            | 0       |
| complexity            | 14         | 14            | 0       |
| firebase              | 29         | 29            | 0       |
| memory_management     | 13         | 13            | 0       |
| return                | 7          | 7             | 0       |
| stylistic_additional  | 24         | 24            | 0       |
| web                   | 8          | 8             | 0       |
| animation             | 19         | 19            | 0       |
| config                | 7          | 7             | 0       |
| connectivity          | 3          | 3             | 0       |
| freezed               | 10         | 10            | 0       |
| isar                  | 21         | 21            | 0       |
| notification         | 8          | 8             | 0       |
| sqflite               | 2          | 2             | 0       |
| type_safety           | 17         | 17            | 0       |
| ui_ux                 | 20         | 20            | 0       |
| widget_lifecycle      | 36         | 36            | 0       |

---

## 3. Rule instantiation tests — Done for 99 categories

All 99 category test files have a “Rule Instantiation” group (one test per rule: instantiate, assert `code.name`, `problemMessage` contains `[code_name]`, length &gt; 50, `correctionMessage` non-null).

**Publish script:** Rule-instantiation status is derived in `scripts/modules/_rule_metrics.py` (`_compute_rule_instantiation_stats`): it scans each `test/{category}_rules_test.dart` for the string `Rule Instantiation`. The “Test Coverage” report shows a “Rule inst.” line. This document is for human reference only; the script does not read it.

---

## 4. Why the publish report shows Fixtures &lt; 100%

- **A. code_quality:** Four categories (`code_quality_avoid`, `code_quality_control_flow`, `code_quality_prefer`, `code_quality_variables`) in `lib/src/rules/code_quality/*.dart` share one fixture dir: `example_core/lib/code_quality/` (104 `*_fixture.dart` files). `_count_fixtures_for_category` in `scripts/modules/_rule_metrics.py` must, for each of these categories, count only fixtures whose basename is in that category’s `rule_names`, and must resolve the fixture dir to `example_core` (see **Remaining work §1**). Until that fix is in place, the report undercounts and shows &lt;100%.

- **B. isar:** Fixed. `_strip_line_comments` in `_rule_metrics.py` is applied before `_RULE_CLASS_RE` in `count_rules` and `_collect_category_rules`, so the commented-out class in `lib/src/rules/packages/isar_rules.dart` is not counted.

- **C. Real missing fixtures:** Any rule in the §6.3 table that still has no `{rule_name}_fixture.dart` in the stated directory contributes to the gap. See **Remaining work §3** for the exact paths to check.

---

## 5. Real behavioral tests — Started

Integration tests in `test/fixture_lint_integration_test.dart`: run custom_lint on example_async and assert expected rule codes when violations exist; assert compliant-only fixture has zero violations. Full per-rule behavioral coverage (violating → lint, compliant → no lint) is not yet done.

**Recommendation:** Add more rules to the expected list and/or a test pattern for at least high-impact rules (security, accessibility, error_handling, async). Priority: one test “violating code → expect lint”; one test “compliant code → expect no lint.”

---

## 6. Checklist (reference; most items done)

### 6.0) Baseline

- [x] Run the publish coverage report and record (2026-03-02): **Fixtures 1962/1990 (98.6%)**.

### 6.1) Fix metrics: code_quality_* categories — **NOT DONE**

- [ ] Implement the change described in **Remaining work §1** in `scripts/modules/_rule_metrics.py` in `_count_fixtures_for_category`: for `category.startswith("code_quality_")`, resolve fixture dir to `example_core/lib/code_quality/` and return `len(basenames.intersection(rule_names))` (rule_names are already passed in by the caller).

### 6.2) Fix metrics: commented-out rule classes — **DONE**

- [x] Strip comment lines before counting rule classes so Isar’s commented-out class is not counted.

### 6.3) Add real missing fixture files (if any)

**No stubs.** Exact paths to check (and add if missing) are in **Remaining work §3**. When adding: rule must be implemented and the BAD example must trigger the linter; validate with `dart run custom_lint` in the example package. One BAD (`// expect_lint: rule_name`) + one GOOD example per file.

| Category        | Rule(s) | Directory |
|-----------------|--------|-----------|
| architecture    | ~~`prefer_builder_pattern`~~ | Rule not implemented (empty `runWithReporter`); stub fixture removed. Do not add fixture until rule is implemented. |
| async           | `avoid_void_async` | `example_async/lib/async/` |
| class_constructor | `prefer_final_fields_always` | `example_core/lib/class_constructor/` |
| config          | `prefer_compile_time_config`, `prefer_flavor_configuration` | `example_async/lib/config/` |
| connectivity    | `prefer_connectivity_debounce` | `example_async/lib/connectivity/` |
| freezed         | `prefer_freezed_union_types` | `example_packages/lib/freezed/` |
| json_datetime   | `prefer_correct_json_casts` | `example_async/lib/json_datetime/` |
| navigation      | `prefer_go_router_builder` | `example_widgets/lib/navigation/` |
| auto_route      | `prefer_auto_route_path_params_simple`, `prefer_auto_route_typed_args` | `example_packages/lib/auto_route/` |
| bloc            | `avoid_cubit_usage` | `example_packages/lib/bloc/` |
| firebase        | `prefer_firebase_transaction_for_counters`, `prefer_correct_topics`, `prefer_deep_link_auth` | `example_packages/lib/firebase/` |
| geolocator      | `prefer_geolocation_coarse_location` | `example_packages/lib/geolocator/` |
| getx            | `avoid_getx_rx_nested_obs` | `example_packages/lib/getx/` |
| riverpod        | `avoid_riverpod_string_provider_name` | `example_packages/lib/riverpod/` |
| performance     | `prefer_disk_cache_for_persistence` | `example_async/lib/performance/` |
| record_pattern  | `prefer_class_destructuring` | `example_core/lib/record_pattern/` |
| return          | `avoid_returning_this` | `example_core/lib/return/` |
| stylistic       | `prefer_expression_body_getters`, `prefer_block_body_setters` | `example_style/lib/stylistic/` |
| theming         | `prefer_dark_mode_colors`, `prefer_high_contrast_mode` | `example_widgets/lib/theming/` |
| widget_layout   | `prefer_flex_for_complex_layout`, `prefer_find_child_index_callback` | `example_widgets/lib/widget_layout/` |
| widget_patterns | `avoid_bool_in_widget_constructors`, `avoid_unnecessary_containers`, `prefer_const_literals_to_create_immutables` | `example_widgets/lib/widget_patterns/` |

### 6.4) Test fixture lists and Rule Instantiation — **DONE**

- [x] Fixture lists and Rule Instantiation tests for §6.3 rules are present in the relevant `test/{category}_rules_test.dart` files.

### 6.5) Verify — **NOT DONE**

- [ ] After §6.1 (and any §6.3 gaps): run `python scripts/publish.py` and in the Test Coverage block confirm **Fixtures** shows 100% (e.g. 1990/1990).
- [ ] Run `dart test` from repo root; fix any failing tests.

---

## 7. Summary

| Need | Status |
|------|--------|
| Fixtures (per-rule in 27 reviewed categories) | **Done** |
| Rule instantiation tests (99 categories) | **Done** |
| Real behavioral tests (linter on code) | **In progress** (optional: add more rules to integration test) |
| Publish report Fixtures = 100% | **Not done** — see **Remaining work** at top |

For completed batch details: `bugs/history/unit_test_coverage_fixtures_and_instantiation_completed.md`, `bugs/history/unit_test_coverage_batch_2026-03-03.md`.

---

## 8. Full checklist: all remaining unit tests

This section lists **every** remaining unit test to add. Each item = add that rule code to `expectedFromFixtures` in `test/fixture_lint_integration_test.dart` (around line 75), then run `dart test test/fixture_lint_integration_test.dart` to confirm. Rules are grouped by fixture directory under `example_async/lib/`. **57 rules are already in the list**; the checkboxes below are for the rest.

### Other remaining work (metric + verify)

- [ ] **Metric fix:** Implement **Remaining work §1** in `scripts/modules/_rule_metrics.py` (`_count_fixtures_for_category`: code_quality_* → example_core only).
- [ ] **Verify:** Run `python scripts/publish.py` and confirm Test Coverage shows Fixtures 100%.
- [ ] **Verify:** Run `dart test`; fix any failures.

### api (`example_async/lib/api/`)

- [ ] Add to expectedFromFixtures: prefer_dio_over_http
- [ ] Add to expectedFromFixtures: prefer_timeout_on_requests

### api_network

- [ ] Add to expectedFromFixtures: avoid_cached_image_in_build
- [ ] Add to expectedFromFixtures: avoid_hardcoded_api_urls
- [ ] Add to expectedFromFixtures: avoid_over_fetching
- [ ] Add to expectedFromFixtures: avoid_redundant_requests
- [ ] Add to expectedFromFixtures: prefer_api_pagination
- [ ] Add to expectedFromFixtures: prefer_http_connection_reuse
- [ ] Add to expectedFromFixtures: prefer_streaming_response
- [ ] Add to expectedFromFixtures: require_analytics_event_naming
- [ ] Add to expectedFromFixtures: require_content_type_check
- [ ] Add to expectedFromFixtures: require_geolocator_timeout
- [ ] Add to expectedFromFixtures: require_http_status_check
- [ ] Add to expectedFromFixtures: require_image_picker_error_handling
- [ ] Add to expectedFromFixtures: require_image_picker_result_handling
- [ ] Add to expectedFromFixtures: require_image_picker_source_choice
- [ ] Add to expectedFromFixtures: require_notification_handler_top_level
- [ ] Add to expectedFromFixtures: require_notification_permission_android13
- [ ] Add to expectedFromFixtures: require_offline_indicator
- [ ] Add to expectedFromFixtures: require_permission_denied_handling
- [ ] Add to expectedFromFixtures: require_permission_rationale
- [ ] Add to expectedFromFixtures: require_permission_status_check
- [ ] Add to expectedFromFixtures: require_request_timeout
- [ ] Add to expectedFromFixtures: require_response_caching
- [ ] Add to expectedFromFixtures: require_retry_logic
- [ ] Add to expectedFromFixtures: require_sqflite_migration
- [ ] Add to expectedFromFixtures: require_typed_api_response
- [ ] Add to expectedFromFixtures: require_url_launcher_error_handling
- [ ] Add to expectedFromFixtures: require_websocket_error_handling

### async

- [ ] Add to expectedFromFixtures: avoid_future_ignore
- [ ] Add to expectedFromFixtures: avoid_future_in_build
- [ ] Add to expectedFromFixtures: avoid_future_tostring
- [ ] Add to expectedFromFixtures: avoid_multiple_stream_listeners
- [ ] Add to expectedFromFixtures: avoid_nested_futures
- [ ] Add to expectedFromFixtures: avoid_redundant_async
- [ ] Add to expectedFromFixtures: avoid_sequential_awaits
- [ ] Add to expectedFromFixtures: avoid_stream_sync_events
- [ ] Add to expectedFromFixtures: avoid_stream_tostring
- [ ] Add to expectedFromFixtures: avoid_sync_on_every_change
- [ ] Add to expectedFromFixtures: prefer_assigning_await_expressions
- [ ] Add to expectedFromFixtures: prefer_async_await
- [ ] Add to expectedFromFixtures: prefer_async_callback
- [ ] Add to expectedFromFixtures: prefer_async_init_state
- [ ] Add to expectedFromFixtures: prefer_broadcast_stream
- [ ] Add to expectedFromFixtures: prefer_commenting_future_delayed
- [ ] Add to expectedFromFixtures: prefer_correct_future_return_type
- [ ] Add to expectedFromFixtures: prefer_future_void_function_over_async_callback
- [ ] Add to expectedFromFixtures: prefer_isolate_for_heavy_compute
- [ ] Add to expectedFromFixtures: prefer_return_await
- [ ] Add to expectedFromFixtures: prefer_stream_distinct
- [ ] Add to expectedFromFixtures: prefer_utc_for_storage
- [ ] Add to expectedFromFixtures: require_cache_ttl
- [ ] Add to expectedFromFixtures: require_future_timeout
- [ ] Add to expectedFromFixtures: require_location_timeout
- [ ] Add to expectedFromFixtures: require_mounted_check_after_await
- [ ] Add to expectedFromFixtures: require_network_status_check
- [ ] Add to expectedFromFixtures: require_pending_changes_indicator
- [ ] Add to expectedFromFixtures: require_stream_controller_dispose
- [ ] Add to expectedFromFixtures: require_stream_error_handling
- [ ] Add to expectedFromFixtures: require_stream_on_done
- [ ] Add to expectedFromFixtures: require_websocket_message_validation
- [ ] Add to expectedFromFixtures: require_websocket_reconnection
- [ ] Add to expectedFromFixtures: use_setstate_synchronously

### bluetooth_hardware

- [ ] Add to expectedFromFixtures: avoid_bluetooth_scan_without_timeout
- [ ] Add to expectedFromFixtures: prefer_ble_mtu_negotiation
- [ ] Add to expectedFromFixtures: require_audio_focus_handling
- [ ] Add to expectedFromFixtures: require_ble_disconnect_handling
- [ ] Add to expectedFromFixtures: require_geolocator_error_handling
- [ ] Add to expectedFromFixtures: require_geolocator_permission_check
- [ ] Add to expectedFromFixtures: require_geolocator_service_enabled
- [ ] Add to expectedFromFixtures: require_geolocator_stream_cancel
- [ ] Add to expectedFromFixtures: require_qr_permission_check

### config

- [ ] Add to expectedFromFixtures: avoid_hardcoded_config_test
- [ ] Add to expectedFromFixtures: avoid_platform_specific_imports
- [ ] Add to expectedFromFixtures: avoid_string_env_parsing
- [ ] Add to expectedFromFixtures: require_feature_flag_type_safety

### connectivity

- [ ] Add to expectedFromFixtures: avoid_connectivity_equals_internet
- [ ] Add to expectedFromFixtures: require_connectivity_error_handling

### context

- [ ] Add to expectedFromFixtures: avoid_context_after_await_in_static
- [ ] Add to expectedFromFixtures: avoid_context_dependency_in_callback
- [ ] Add to expectedFromFixtures: avoid_context_in_async_static
- [ ] Add to expectedFromFixtures: avoid_context_in_static_methods
- [ ] Add to expectedFromFixtures: avoid_storing_context

### crypto

- [ ] Add to expectedFromFixtures: avoid_deprecated_crypto_algorithms
- [ ] Add to expectedFromFixtures: require_unique_iv_per_encryption

### debug

- [ ] Add to expectedFromFixtures: avoid_debug_print
- [ ] Add to expectedFromFixtures: avoid_print_in_production
- [ ] Add to expectedFromFixtures: avoid_print_in_release
- [ ] Add to expectedFromFixtures: avoid_sensitive_in_logs
- [ ] Add to expectedFromFixtures: avoid_unguarded_debug
- [ ] Add to expectedFromFixtures: prefer_commenting_analyzer_ignores
- [ ] Add to expectedFromFixtures: prefer_debugPrint
- [ ] Add to expectedFromFixtures: require_log_level_for_production
- [ ] Add to expectedFromFixtures: require_structured_logging

### disposal

- [ ] Add to expectedFromFixtures: avoid_hive_binary_storage
- [ ] Add to expectedFromFixtures: avoid_hive_field_index_reuse
- [ ] Add to expectedFromFixtures: avoid_shared_prefs_in_isolate
- [ ] Add to expectedFromFixtures: avoid_sqflite_reserved_words
- [ ] Add to expectedFromFixtures: avoid_websocket_memory_leak
- [ ] Add to expectedFromFixtures: dispose_class_fields
- [ ] Add to expectedFromFixtures: prefer_dispose_before_new_instance
- [ ] Add to expectedFromFixtures: prefer_hive_lazy_box
- [ ] Add to expectedFromFixtures: prefer_shared_prefs_async_api
- [ ] Add to expectedFromFixtures: require_change_notifier_dispose
- [ ] Add to expectedFromFixtures: require_debouncer_cancel
- [ ] Add to expectedFromFixtures: require_file_handle_close
- [ ] Add to expectedFromFixtures: require_interval_timer_cancel
- [ ] Add to expectedFromFixtures: require_lifecycle_observer
- [ ] Add to expectedFromFixtures: require_media_player_dispose
- [ ] Add to expectedFromFixtures: require_page_controller_dispose
- [ ] Add to expectedFromFixtures: require_receive_port_close
- [ ] Add to expectedFromFixtures: require_shared_prefs_prefix
- [ ] Add to expectedFromFixtures: require_socket_close
- [ ] Add to expectedFromFixtures: require_sse_subscription_cancel
- [ ] Add to expectedFromFixtures: require_tab_controller_dispose
- [ ] Add to expectedFromFixtures: require_text_editing_controller_dispose
- [ ] Add to expectedFromFixtures: require_video_player_controller_dispose

### error_handling

- [ ] Add to expectedFromFixtures: avoid_catch_exception_alone
- [ ] Add to expectedFromFixtures: avoid_generic_exceptions
- [ ] Add to expectedFromFixtures: avoid_nested_try_statements
- [ ] Add to expectedFromFixtures: avoid_print_error
- [ ] Add to expectedFromFixtures: avoid_swallowing_exceptions
- [ ] Add to expectedFromFixtures: prefer_result_pattern
- [ ] Add to expectedFromFixtures: require_app_startup_error_handling
- [ ] Add to expectedFromFixtures: require_async_error_documentation
- [ ] Add to expectedFromFixtures: require_cache_key_determinism
- [ ] Add to expectedFromFixtures: require_error_boundary
- [ ] Add to expectedFromFixtures: require_error_context
- [ ] Add to expectedFromFixtures: require_finally_cleanup
- [ ] Add to expectedFromFixtures: require_notification_action_handling
- [ ] Add to expectedFromFixtures: require_permission_permanent_denial_handling

### file_handling

- [ ] Add to expectedFromFixtures: avoid_loading_full_pdf_in_memory
- [ ] Add to expectedFromFixtures: prefer_sqflite_batch
- [ ] Add to expectedFromFixtures: prefer_sqflite_column_constants
- [ ] Add to expectedFromFixtures: prefer_sqflite_singleton
- [ ] Add to expectedFromFixtures: prefer_streaming_for_large_files
- [ ] Add to expectedFromFixtures: require_file_exists_check
- [ ] Add to expectedFromFixtures: require_file_path_sanitization
- [ ] Add to expectedFromFixtures: require_graphql_error_handling
- [ ] Add to expectedFromFixtures: require_pdf_error_handling
- [ ] Add to expectedFromFixtures: require_sqflite_error_handling
- [ ] Add to expectedFromFixtures: require_sqflite_transaction
- [ ] Add to expectedFromFixtures: require_sqflite_whereargs

### iap

- [ ] Add to expectedFromFixtures: avoid_entitlement_without_server
- [ ] Add to expectedFromFixtures: avoid_purchase_in_sandbox_production
- [ ] Add to expectedFromFixtures: require_price_localization
- [ ] Add to expectedFromFixtures: require_subscription_status_check

### json

- [ ] Add to expectedFromFixtures: avoid_datetime_parse_unvalidated
- [ ] Add to expectedFromFixtures: avoid_double_for_money
- [ ] Add to expectedFromFixtures: avoid_hardcoded_config
- [ ] Add to expectedFromFixtures: avoid_mixed_environments
- [ ] Add to expectedFromFixtures: avoid_optional_field_crash
- [ ] Add to expectedFromFixtures: avoid_sensitive_in_logs
- [ ] Add to expectedFromFixtures: prefer_explicit_json_keys
- [ ] Add to expectedFromFixtures: prefer_iso8601_dates
- [ ] Add to expectedFromFixtures: prefer_try_parse_for_dynamic_data
- [ ] Add to expectedFromFixtures: require_date_format_specification
- [ ] Add to expectedFromFixtures: require_json_decode_try_catch

### json_datetime

- [ ] Add to expectedFromFixtures: avoid_datetime_now_in_tests
- [ ] Add to expectedFromFixtures: prefer_duration_constants
- [ ] Add to expectedFromFixtures: prefer_json_serializable
- [ ] Add to expectedFromFixtures: require_json_schema_validation
- [ ] Add to expectedFromFixtures: require_timezone_display

### lifecycle

- [ ] Add to expectedFromFixtures: avoid_work_in_paused_state
- [ ] Add to expectedFromFixtures: require_app_lifecycle_handling
- [ ] Add to expectedFromFixtures: require_did_update_widget_check
- [ ] Add to expectedFromFixtures: require_late_initialization_in_init_state
- [ ] Add to expectedFromFixtures: require_resume_state_refresh
- [ ] Add to expectedFromFixtures: require_widgets_binding_callback

### media

- [ ] Add to expectedFromFixtures: avoid_autoplay_audio
- [ ] Add to expectedFromFixtures: prefer_audio_session_config
- [ ] Add to expectedFromFixtures: prefer_camera_resolution_selection

### memory

- [ ] Add to expectedFromFixtures: avoid_unbounded_cache_growth

### memory_management

- [ ] Add to expectedFromFixtures: avoid_capturing_this_in_callbacks
- [ ] Add to expectedFromFixtures: avoid_expando_circular_references
- [ ] Add to expectedFromFixtures: avoid_large_isolate_communication
- [ ] Add to expectedFromFixtures: avoid_large_objects_in_state
- [ ] Add to expectedFromFixtures: avoid_retaining_disposed_widgets
- [ ] Add to expectedFromFixtures: prefer_weak_references_for_cache
- [ ] Add to expectedFromFixtures: require_cache_eviction_policy
- [ ] Add to expectedFromFixtures: require_cache_expiration
- [ ] Add to expectedFromFixtures: require_cache_key_uniqueness
- [ ] Add to expectedFromFixtures: require_image_disposal

### money

- [ ] Add to expectedFromFixtures: require_currency_code_with_amount

### notification

- [ ] Add to expectedFromFixtures: avoid_notification_payload_sensitive
- [ ] Add to expectedFromFixtures: avoid_notification_same_id
- [ ] Add to expectedFromFixtures: avoid_notification_silent_failure
- [ ] Add to expectedFromFixtures: prefer_notification_grouping
- [ ] Add to expectedFromFixtures: require_notification_channel_android
- [ ] Add to expectedFromFixtures: require_notification_timezone_awareness

### performance

- [ ] Add to expectedFromFixtures: avoid_animation_in_large_list
- [ ] Add to expectedFromFixtures: avoid_blocking_main_thread
- [ ] Add to expectedFromFixtures: avoid_calling_of_in_build
- [ ] Add to expectedFromFixtures: avoid_closure_memory_leak
- [ ] Add to expectedFromFixtures: avoid_excessive_widget_depth
- [ ] Add to expectedFromFixtures: avoid_expensive_computation_in_build
- [ ] Add to expectedFromFixtures: avoid_finalizer_misuse
- [ ] Add to expectedFromFixtures: avoid_json_in_main
- [ ] Add to expectedFromFixtures: avoid_large_list_copy
- [ ] Add to expectedFromFixtures: avoid_memory_intensive_operations
- [ ] Add to expectedFromFixtures: avoid_money_arithmetic_on_double
- [ ] Add to expectedFromFixtures: avoid_setstate_in_build
- [ ] Add to expectedFromFixtures: avoid_text_span_in_build
- [ ] Add to expectedFromFixtures: prefer_cached_getter
- [ ] Add to expectedFromFixtures: prefer_compute_for_heavy_work
- [ ] Add to expectedFromFixtures: prefer_disk_cache_for_persistence
- [ ] Add to expectedFromFixtures: prefer_element_rebuild
- [ ] Add to expectedFromFixtures: prefer_image_precache
- [ ] Add to expectedFromFixtures: prefer_inherited_widget_cache
- [ ] Add to expectedFromFixtures: prefer_static_const_widgets
- [ ] Add to expectedFromFixtures: prefer_value_listenable_builder
- [ ] Add to expectedFromFixtures: require_dispose_pattern
- [ ] Add to expectedFromFixtures: require_image_cache_management
- [ ] Add to expectedFromFixtures: require_isolate_for_heavy
- [ ] Add to expectedFromFixtures: require_keys_in_animated_lists
- [ ] Add to expectedFromFixtures: require_menu_bar_for_desktop
- [ ] Add to expectedFromFixtures: require_repaint_boundary
- [ ] Add to expectedFromFixtures: require_widget_key_strategy
- [ ] Add to expectedFromFixtures: require_window_close_confirmation

### permission

- [ ] Add to expectedFromFixtures: avoid_permission_handler_null_safety
- [ ] Add to expectedFromFixtures: avoid_permission_request_loop
- [ ] Add to expectedFromFixtures: prefer_image_cropping
- [ ] Add to expectedFromFixtures: require_camera_permission_check
- [ ] Add to expectedFromFixtures: require_location_permission_rationale

### resource_management

- [ ] Add to expectedFromFixtures: avoid_image_picker_without_source
- [ ] Add to expectedFromFixtures: prefer_coarse_location_when_sufficient
- [ ] Add to expectedFromFixtures: prefer_geolocator_accuracy_appropriate
- [ ] Add to expectedFromFixtures: require_camera_dispose
- [ ] Add to expectedFromFixtures: require_database_close
- [ ] Add to expectedFromFixtures: require_file_close_in_finally
- [ ] Add to expectedFromFixtures: require_http_client_close
- [ ] Add to expectedFromFixtures: require_image_compression
- [ ] Add to expectedFromFixtures: require_isolate_kill
- [ ] Add to expectedFromFixtures: require_platform_channel_cleanup
- [ ] Add to expectedFromFixtures: require_websocket_close

### security

- [ ] Add to expectedFromFixtures: avoid_api_key_in_code
- [ ] Add to expectedFromFixtures: avoid_auth_in_query_params
- [ ] Add to expectedFromFixtures: avoid_clipboard_sensitive
- [ ] Add to expectedFromFixtures: avoid_dynamic_code_loading
- [ ] Add to expectedFromFixtures: avoid_dynamic_sql
- [ ] Add to expectedFromFixtures: avoid_encryption_key_in_memory
- [ ] Add to expectedFromFixtures: avoid_eval_like_patterns
- [ ] Add to expectedFromFixtures: avoid_external_storage_sensitive
- [ ] Add to expectedFromFixtures: avoid_generic_key_in_url
- [ ] Add to expectedFromFixtures: avoid_hardcoded_credentials
- [ ] Add to expectedFromFixtures: avoid_hardcoded_signing_config
- [ ] Add to expectedFromFixtures: avoid_ignoring_ssl_errors
- [ ] Add to expectedFromFixtures: avoid_jwt_decode_client
- [ ] Add to expectedFromFixtures: avoid_logging_sensitive_data
- [ ] Add to expectedFromFixtures: avoid_path_traversal
- [ ] Add to expectedFromFixtures: avoid_redirect_injection
- [ ] Add to expectedFromFixtures: avoid_screenshot_sensitive
- [ ] Add to expectedFromFixtures: avoid_secure_storage_large_data
- [ ] Add to expectedFromFixtures: avoid_sensitive_data_in_clipboard
- [ ] Add to expectedFromFixtures: avoid_stack_trace_in_production
- [ ] Add to expectedFromFixtures: avoid_storing_passwords
- [ ] Add to expectedFromFixtures: avoid_storing_sensitive_unencrypted
- [ ] Add to expectedFromFixtures: avoid_token_in_url
- [ ] Add to expectedFromFixtures: avoid_unnecessary_to_list
- [ ] Add to expectedFromFixtures: avoid_unsafe_deserialization
- [ ] Add to expectedFromFixtures: avoid_unverified_native_library
- [ ] Add to expectedFromFixtures: avoid_user_controlled_urls
- [ ] Add to expectedFromFixtures: avoid_webview_cors_issues
- [ ] Add to expectedFromFixtures: avoid_webview_insecure_content
- [ ] Add to expectedFromFixtures: avoid_webview_javascript_enabled
- [ ] Add to expectedFromFixtures: prefer_data_masking
- [ ] Add to expectedFromFixtures: prefer_html_escape
- [ ] Add to expectedFromFixtures: prefer_local_auth
- [ ] Add to expectedFromFixtures: prefer_secure_random
- [ ] Add to expectedFromFixtures: prefer_typed_data
- [ ] Add to expectedFromFixtures: prefer_webview_javascript_disabled
- [ ] Add to expectedFromFixtures: require_auth_check
- [ ] Add to expectedFromFixtures: require_biometric_fallback
- [ ] Add to expectedFromFixtures: require_catch_logging
- [ ] Add to expectedFromFixtures: require_certificate_pinning
- [ ] Add to expectedFromFixtures: require_clipboard_paste_validation
- [ ] Add to expectedFromFixtures: require_data_encryption
- [ ] Add to expectedFromFixtures: require_deep_link_validation
- [ ] Add to expectedFromFixtures: require_https_only
- [ ] Add to expectedFromFixtures: require_https_only_test
- [ ] Add to expectedFromFixtures: require_input_sanitization
- [ ] Add to expectedFromFixtures: require_logout_cleanup
- [ ] Add to expectedFromFixtures: require_secure_password_field
- [ ] Add to expectedFromFixtures: require_secure_storage
- [ ] Add to expectedFromFixtures: require_secure_storage_auth_data
- [ ] Add to expectedFromFixtures: require_secure_storage_error_handling
- [ ] Add to expectedFromFixtures: require_secure_storage_for_auth
- [ ] Add to expectedFromFixtures: require_token_refresh
- [ ] Add to expectedFromFixtures: require_url_validation
- [ ] Add to expectedFromFixtures: require_webview_error_handling

### state_management

- [ ] Add to expectedFromFixtures: avoid_getx_global_state
- [ ] Add to expectedFromFixtures: avoid_getx_static_context
- [ ] Add to expectedFromFixtures: avoid_global_key_in_build
- [ ] Add to expectedFromFixtures: avoid_large_bloc
- [ ] Add to expectedFromFixtures: avoid_riverpod_for_network_only
- [ ] Add to expectedFromFixtures: avoid_setstate_in_large_state_class
- [ ] Add to expectedFromFixtures: avoid_stateful_without_state
- [ ] Add to expectedFromFixtures: avoid_static_state
- [ ] Add to expectedFromFixtures: prefer_bloc_transform
- [ ] Add to expectedFromFixtures: prefer_change_notifier_proxy
- [ ] Add to expectedFromFixtures: prefer_change_notifier_proxy_provider
- [ ] Add to expectedFromFixtures: prefer_immutable_selector_value
- [ ] Add to expectedFromFixtures: prefer_selector_widget
- [ ] Add to expectedFromFixtures: require_bloc_event_sealed
- [ ] Add to expectedFromFixtures: require_bloc_repository_abstraction
- [ ] Add to expectedFromFixtures: require_mounted_check
- [ ] Add to expectedFromFixtures: require_notify_listeners
- [ ] Add to expectedFromFixtures: require_value_notifier_dispose
