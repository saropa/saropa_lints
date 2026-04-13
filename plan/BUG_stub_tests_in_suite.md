# BUG: 1,646 stub tests that always pass without testing anything

**Severity**: High — test suite gives partial false confidence
**Date**: 2026-03-25 (updated 2026-04-04)
**Status**: In Progress — ~54% of original stubs converted

## Summary

35% of the test suite (1,646 of 4,690 `test()` calls across 66 of 155 test files) are stubs that assert a string literal is not null. They always pass regardless of whether the rule they claim to test works, is registered, or even exists.

```dart
// This is the pattern — it can NEVER fail
test('avoid_icon_buttons_without_tooltip SHOULD trigger', () {
  expect('avoid_icon_buttons_without_tooltip detected', isNotNull);
});
```

A second pattern (`expect(true, isTrue)`) accounts for 16 additional stubs in `false_positive_fixes_test.dart`.

### Progress Since Discovery

When this bug was filed (2026-03-25), there were 3,530 stubs across 103 files. As of 2026-04-04, 1,884 stubs have been converted to real tests — a 53% reduction. The overall real-test ratio improved from 26% to 65%.

## Impact

- **No regression protection**: A rule could be deleted, deregistered, or broken and every stub "test" would still pass.
- **False confidence**: `dart test` reports ~4,700 passing tests. Only ~3,044 actually test behavior.
- **Masked real bugs**: The `avoid_global_state` false-positive bugs went undetected because the tests for that rule were stubs.

## Complete Inventory

### Files sorted by stub count (66 files, 1,646 stubs total)

| File | Total | Stubs | Real | Stub % |
|------|-------|-------|------|--------|
| widget_patterns_rules_test.dart | 108 | 99 | 9 | 91% |
| code_quality_rules_test.dart | 130 | 98 | 32 | 75% |
| ios_rules_test.dart | 117 | 88 | 29 | 75% |
| widget_layout_rules_test.dart | 79 | 73 | 6 | 92% |
| security_rules_test.dart | 78 | 56 | 22 | 71% |
| bloc_rules_test.dart | 96 | 48 | 48 | 50% |
| async_rules_test.dart | 68 | 48 | 20 | 70% |
| performance_rules_test.dart | 99 | 46 | 53 | 46% |
| accessibility_rules_test.dart | 82 | 39 | 43 | 47% |
| riverpod_rules_test.dart | 73 | 38 | 35 | 52% |
| api_network_rules_test.dart | 78 | 38 | 40 | 48% |
| navigation_rules_test.dart | 78 | 36 | 42 | 46% |
| widget_lifecycle_rules_test.dart | 73 | 35 | 38 | 47% |
| testing_best_practices_rules_test.dart | 72 | 35 | 37 | 48% |
| structure_rules_test.dart | 87 | 33 | 54 | 37% |
| test_rules_test.dart | 66 | 32 | 34 | 48% |
| firebase_rules_test.dart | 73 | 29 | 44 | 39% |
| control_flow_rules_test.dart | 66 | 28 | 38 | 42% |
| stylistic_rules_test.dart | 76 | 27 | 49 | 35% |
| internationalization_rules_test.dart | 55 | 26 | 29 | 47% |
| forms_rules_test.dart | 54 | 26 | 28 | 48% |
| false_positive_fixes_test.dart | 158 | 26 | 132 | 16% |
| provider_rules_test.dart | 49 | 23 | 26 | 46% |
| naming_style_rules_test.dart | 55 | 23 | 32 | 41% |
| collection_rules_test.dart | 73 | 23 | 50 | 31% |
| getx_rules_test.dart | 46 | 22 | 24 | 47% |
| stylistic_additional_rules_test.dart | 51 | 21 | 30 | 41% |
| isar_rules_test.dart | 44 | 21 | 23 | 47% |
| image_rules_test.dart | 44 | 21 | 23 | 47% |
| ui_ux_rules_test.dart | 44 | 20 | 24 | 45% |
| hive_rules_test.dart | 42 | 20 | 22 | 47% |
| error_handling_rules_test.dart | 67 | 20 | 47 | 29% |
| record_pattern_rules_test.dart | 40 | 19 | 21 | 47% |
| package_specific_rules_test.dart | 40 | 19 | 21 | 47% |
| animation_rules_test.dart | 40 | 19 | 21 | 47% |
| scroll_rules_test.dart | 36 | 17 | 19 | 47% |
| disposal_rules_test.dart | 54 | 17 | 37 | 31% |
| type_safety_rules_test.dart | 34 | 16 | 18 | 47% |
| stylistic_whitespace_constructor_rules_test.dart | 36 | 15 | 21 | 41% |
| macos_rules_test.dart | 32 | 15 | 17 | 46% |
| file_handling_rules_test.dart | 34 | 15 | 19 | 44% |
| dependency_injection_rules_test.dart | 32 | 15 | 17 | 46% |
| type_rules_test.dart | 45 | 14 | 31 | 31% |
| stylistic_null_collection_rules_test.dart | 30 | 14 | 16 | 46% |
| stylistic_error_testing_rules_test.dart | 32 | 14 | 18 | 43% |
| resource_management_rules_test.dart | 30 | 14 | 16 | 46% |
| formatting_rules_test.dart | 50 | 14 | 36 | 28% |
| dio_rules_test.dart | 30 | 14 | 16 | 46% |
| class_constructor_rules_test.dart | 30 | 14 | 16 | 46% |
| unnecessary_code_rules_test.dart | 30 | 13 | 17 | 43% |
| stylistic_widget_rules_test.dart | 28 | 13 | 15 | 46% |
| json_datetime_rules_test.dart | 28 | 13 | 15 | 46% |
| equatable_rules_test.dart | 28 | 13 | 15 | 46% |
| shared_preferences_rules_test.dart | 26 | 12 | 14 | 46% |
| complexity_rules_test.dart | 42 | 12 | 30 | 28% |
| stylistic_control_flow_rules_test.dart | 41 | 11 | 30 | 26% |
| numeric_literal_rules_test.dart | 30 | 11 | 19 | 36% |
| memory_management_rules_test.dart | 36 | 11 | 25 | 30% |
| build_method_rules_test.dart | 24 | 11 | 13 | 45% |
| state_management_rules_test.dart | 22 | 10 | 12 | 45% |
| bluetooth_hardware_rules_test.dart | 22 | 10 | 12 | 45% |
| false_positive_prevention_test.dart | 31 | 9 | 22 | 29% |
| auto_route_rules_test.dart | 26 | 8 | 18 | 30% |
| url_launcher_rules_test.dart | 11 | 3 | 8 | 27% |
| rxdart_rules_test.dart | 7 | 2 | 5 | 28% |
| migration_rules_test.dart | 95 | 1 | 94 | 1% |

### Files with zero stubs (89 clean files)

These files contain only real tests and should be used as reference for the pattern to follow:

- analysis_options_rule_packs_test.dart
- analyzer_metadata_compat_utils_test.dart
- android_rules_test.dart
- anti_pattern_detection_test.dart
- architecture_rules_test.dart
- avoid_deprecated_usage_crash_test.dart
- avoid_implicit_animation_dispose_cast_rule_test.dart
- code_line_counting_test.dart
- comment_utils_test.dart
- compile_time_syntax_rules_test.dart
- conditional_import_utils_test.dart
- config_rules_test.dart
- connectivity_rules_test.dart
- context_rules_test.dart
- crypto_rules_test.dart
- dart_sdk_34_deprecation_rules_test.dart
- dart_sdk_3_removal_rules_test.dart
- db_yield_rules_test.dart
- debug_rules_test.dart
- defensive_coding_test.dart
- dialog_snackbar_rules_test.dart
- documentation_rules_test.dart
- drift_rules_test.dart
- element_identifier_utils_test.dart
- equality_rules_test.dart
- exception_rules_test.dart
- fixture_lint_integration_test.dart
- flame_rules_test.dart
- flutter_deprecation_migration_rules_test.dart
- flutter_hooks_rules_test.dart
- flutter_migration_widget_detection_test.dart
- flutter_migration_widget_rules_test.dart
- flutter_test_window_deprecation_utils_test.dart
- freezed_rules_test.dart
- geolocator_rules_test.dart
- get_it_rules_test.dart
- graphql_rules_test.dart
- handle_throwing_invocations_metadata_crash_test.dart
- iap_rules_test.dart
- ignore_utils_test.dart
- image_filter_quality_detection_test.dart
- image_filter_quality_migration_rules_test.dart
- import_graph_tracker_perf_test.dart
- import_graph_tracker_test.dart
- info_plist_utils_test.dart
- lifecycle_rules_test.dart
- linux_rules_test.dart
- listview_extent_metadata_rules_test.dart
- media_rules_test.dart
- money_rules_test.dart
- notification_rules_test.dart
- opt_in_registration_test.dart
- permission_rules_test.dart
- plan_additional_rules_21_30_test.dart
- plan_additional_rules_31_40_test.dart
- platform_rules_test.dart
- prefer_overflow_bar_over_button_bar_rule_test.dart
- prefer_setup_teardown_test.dart
- progress_tracker_dedup_test.dart
- project_info_root_uri_test.dart
- pubspec_lock_resolver_test.dart
- qr_scanner_rules_test.dart
- report_consolidator_test.dart
- require_data_encryption_pin_pattern_test.dart
- require_error_case_tests_test.dart
- return_rules_test.dart
- roadmap_15_rules_test.dart
- roadmap_detail_12_rules_test.dart
- roadmap_detail_9_rules_test.dart
- roadmap_detail_rules_test.dart
- rule_pack_registry_test.dart
- rule_packs_config_test.dart
- rule_packs_pubspec_markers_test.dart
- rule_packs_semver_test.dart
- rule_quick_fix_presence_test.dart
- saropa_lints_test.dart
- saropa_plugin_registration_test.dart
- scan_cli_args_test.dart
- scan_runner_test.dart
- security_rule_metadata_test.dart
- sqflite_rules_test.dart
- supabase_rules_test.dart
- theming_rules_test.dart
- violation_export_test.dart
- violation_parser_test.dart
- web_rules_test.dart
- window_postmessage_scheduling_args_test.dart
- windows_rules_test.dart
- workmanager_rules_test.dart

## Recommended Approach

Replacing the remaining 1,646 stubs is a medium-scale effort. Prioritize by:

1. **Essential-tier rules first** — these run on every project and must work.
2. **Rules with known bugs** — `avoid_global_state` has open bug reports and stub tests.
3. **Rules with quick fixes** — quick fixes can silently break; test coverage is more critical.
4. **Highest stub-count files** — batch replacements in widget_patterns_rules, code_quality_rules, ios_rules, etc.

Each stub replacement requires:
- A fixture file in the appropriate `example*/lib/` directory (or extending an existing one)
- Assertions against actual rule analysis output (violation count, rule name, line number)
- Both positive (SHOULD trigger) and negative (should NOT trigger) cases
