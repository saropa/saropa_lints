# BUG: 3,530 stub tests that always pass without testing anything

**Severity**: Critical — test suite gives false confidence
**Date**: 2026-03-25
**Status**: Open

## Summary

74% of the test suite (3,530 of 4,747 `test()` calls across 103 of 152 test files) are stubs that assert a string literal is not null. They always pass regardless of whether the rule they claim to test works, is registered, or even exists.

```dart
// This is the pattern — it can NEVER fail
test('avoid_icon_buttons_without_tooltip SHOULD trigger', () {
  expect('avoid_icon_buttons_without_tooltip detected', isNotNull);
});
```

A second pattern (`expect(true, isTrue)`) accounts for 16 additional stubs in `false_positive_fixes_test.dart`.

## Impact

- **No regression protection**: A rule could be deleted, deregistered, or broken and every "test" would still pass.
- **False confidence**: `dart test` reports ~4,700 passing tests. Only ~1,200 actually test behavior.
- **Masked real bugs**: The `avoid_global_state` false-positive bugs went undetected because the tests for that rule are stubs.

## Complete Inventory

### Files sorted by stub count (103 files, 3,530 stubs total)

| File | Total | Stubs | Real | Stub % |
|------|-------|-------|------|--------|
| ios_rules_test.dart | 117 | 115 | 2 | 98% |
| code_quality_rules_test.dart | 130 | 109 | 21 | 83% |
| false_positive_fixes_test.dart | 160 | 107 | 53 | 66% |
| widget_patterns_rules_test.dart | 108 | 103 | 5 | 95% |
| performance_rules_test.dart | 99 | 95 | 4 | 95% |
| bloc_rules_test.dart | 96 | 93 | 3 | 96% |
| drift_rules_test.dart | 87 | 83 | 4 | 95% |
| accessibility_rules_test.dart | 82 | 80 | 2 | 97% |
| widget_layout_rules_test.dart | 79 | 77 | 2 | 97% |
| api_network_rules_test.dart | 78 | 76 | 2 | 97% |
| navigation_rules_test.dart | 78 | 75 | 3 | 96% |
| structure_rules_test.dart | 83 | 74 | 9 | 89% |
| security_rules_test.dart | 78 | 72 | 6 | 92% |
| widget_lifecycle_rules_test.dart | 73 | 71 | 2 | 97% |
| riverpod_rules_test.dart | 73 | 71 | 2 | 97% |
| testing_best_practices_rules_test.dart | 72 | 70 | 2 | 97% |
| async_rules_test.dart | 68 | 65 | 3 | 95% |
| test_rules_test.dart | 74 | 64 | 10 | 86% |
| collection_rules_test.dart | 73 | 62 | 11 | 84% |
| firebase_rules_test.dart | 73 | 58 | 15 | 79% |
| stylistic_rules_test.dart | 76 | 57 | 19 | 75% |
| control_flow_rules_test.dart | 66 | 57 | 9 | 86% |
| internationalization_rules_test.dart | 55 | 53 | 2 | 96% |
| forms_rules_test.dart | 54 | 52 | 2 | 96% |
| provider_rules_test.dart | 49 | 47 | 2 | 95% |
| naming_style_rules_test.dart | 55 | 47 | 8 | 85% |
| getx_rules_test.dart | 46 | 44 | 2 | 95% |
| stylistic_additional_rules_test.dart | 51 | 42 | 9 | 82% |
| isar_rules_test.dart | 44 | 42 | 2 | 95% |
| image_rules_test.dart | 44 | 42 | 2 | 95% |
| ui_ux_rules_test.dart | 44 | 41 | 3 | 93% |
| error_handling_rules_test.dart | 67 | 41 | 26 | 61% |
| migration_rules_test.dart | 95 | 40 | 55 | 42% |
| hive_rules_test.dart | 42 | 40 | 2 | 95% |
| record_pattern_rules_test.dart | 40 | 38 | 2 | 95% |
| package_specific_rules_test.dart | 40 | 38 | 2 | 95% |
| animation_rules_test.dart | 40 | 38 | 2 | 95% |
| stylistic_whitespace_constructor_rules_test.dart | 36 | 34 | 2 | 94% |
| scroll_rules_test.dart | 36 | 34 | 2 | 94% |
| disposal_rules_test.dart | 54 | 34 | 20 | 62% |
| type_rules_test.dart | 45 | 33 | 12 | 73% |
| type_safety_rules_test.dart | 34 | 32 | 2 | 94% |
| formatting_rules_test.dart | 50 | 32 | 18 | 64% |
| file_handling_rules_test.dart | 34 | 32 | 2 | 94% |
| documentation_rules_test.dart | 34 | 32 | 2 | 94% |
| stylistic_error_testing_rules_test.dart | 32 | 30 | 2 | 93% |
| macos_rules_test.dart | 32 | 30 | 2 | 93% |
| dependency_injection_rules_test.dart | 32 | 30 | 2 | 93% |
| false_positive_prevention_test.dart | 31 | 29 | 2 | 93% |
| stylistic_null_collection_rules_test.dart | 30 | 28 | 2 | 93% |
| resource_management_rules_test.dart | 30 | 28 | 2 | 93% |
| numeric_literal_rules_test.dart | 31 | 28 | 3 | 90% |
| dio_rules_test.dart | 30 | 28 | 2 | 93% |
| class_constructor_rules_test.dart | 30 | 28 | 2 | 93% |
| config_rules_test.dart | 42 | 27 | 15 | 64% |
| unnecessary_code_rules_test.dart | 30 | 26 | 4 | 86% |
| stylistic_widget_rules_test.dart | 28 | 26 | 2 | 92% |
| json_datetime_rules_test.dart | 28 | 26 | 2 | 92% |
| equatable_rules_test.dart | 28 | 26 | 2 | 92% |
| shared_preferences_rules_test.dart | 26 | 24 | 2 | 92% |
| complexity_rules_test.dart | 42 | 24 | 18 | 57% |
| stylistic_control_flow_rules_test.dart | 41 | 22 | 19 | 53% |
| memory_management_rules_test.dart | 36 | 22 | 14 | 61% |
| build_method_rules_test.dart | 24 | 22 | 2 | 91% |
| state_management_rules_test.dart | 22 | 20 | 2 | 90% |
| bluetooth_hardware_rules_test.dart | 22 | 20 | 2 | 90% |
| architecture_rules_test.dart | 22 | 20 | 2 | 90% |
| auto_route_rules_test.dart | 26 | 19 | 7 | 73% |
| debug_rules_test.dart | 28 | 18 | 10 | 64% |
| freezed_rules_test.dart | 20 | 17 | 3 | 85% |
| equality_rules_test.dart | 25 | 16 | 9 | 64% |
| notification_rules_test.dart | 23 | 14 | 9 | 60% |
| android_rules_test.dart | 16 | 14 | 2 | 87% |
| web_rules_test.dart | 19 | 12 | 7 | 63% |
| permission_rules_test.dart | 14 | 12 | 2 | 85% |
| dialog_snackbar_rules_test.dart | 14 | 12 | 2 | 85% |
| context_rules_test.dart | 19 | 12 | 7 | 63% |
| windows_rules_test.dart | 12 | 10 | 2 | 83% |
| return_rules_test.dart | 25 | 10 | 15 | 40% |
| linux_rules_test.dart | 12 | 10 | 2 | 83% |
| lifecycle_rules_test.dart | 17 | 10 | 7 | 58% |
| flutter_hooks_rules_test.dart | 12 | 10 | 2 | 83% |
| exception_rules_test.dart | 17 | 10 | 7 | 58% |
| crypto_rules_test.dart | 21 | 10 | 11 | 47% |
| url_launcher_rules_test.dart | 12 | 9 | 3 | 75% |
| theming_rules_test.dart | 15 | 8 | 7 | 53% |
| prefer_setup_teardown_test.dart | 13 | 8 | 5 | 61% |
| iap_rules_test.dart | 16 | 8 | 8 | 50% |
| db_yield_rules_test.dart | 12 | 8 | 4 | 66% |
| workmanager_rules_test.dart | 8 | 6 | 2 | 75% |
| supabase_rules_test.dart | 8 | 6 | 2 | 75% |
| qr_scanner_rules_test.dart | 8 | 6 | 2 | 75% |
| platform_rules_test.dart | 11 | 6 | 5 | 54% |
| media_rules_test.dart | 8 | 6 | 2 | 75% |
| get_it_rules_test.dart | 8 | 6 | 2 | 75% |
| geolocator_rules_test.dart | 8 | 6 | 2 | 75% |
| connectivity_rules_test.dart | 10 | 6 | 4 | 60% |
| rxdart_rules_test.dart | 7 | 5 | 2 | 71% |
| money_rules_test.dart | 6 | 4 | 2 | 66% |
| flame_rules_test.dart | 6 | 4 | 2 | 66% |
| sqflite_rules_test.dart | 5 | 2 | 3 | 40% |
| roadmap_15_rules_test.dart | 6 | 2 | 4 | 33% |
| graphql_rules_test.dart | 4 | 2 | 2 | 50% |

### Files with zero stubs (49 clean files)

These files contain only real tests and should be used as reference for the pattern to follow:

- analysis_options_rule_packs_test.dart
- analyzer_metadata_compat_utils_test.dart
- anti_pattern_detection_test.dart
- avoid_deprecated_usage_crash_test.dart
- avoid_implicit_animation_dispose_cast_rule_test.dart
- code_line_counting_test.dart
- comment_utils_test.dart
- compile_time_syntax_rules_test.dart
- conditional_import_utils_test.dart
- dart_sdk_3_removal_rules_test.dart
- defensive_coding_test.dart
- element_identifier_utils_test.dart
- fixture_lint_integration_test.dart
- flutter_migration_widget_detection_test.dart
- flutter_migration_widget_rules_test.dart
- flutter_test_window_deprecation_utils_test.dart
- handle_throwing_invocations_metadata_crash_test.dart
- ignore_utils_test.dart
- image_filter_quality_detection_test.dart
- import_graph_tracker_perf_test.dart
- import_graph_tracker_test.dart
- info_plist_utils_test.dart
- listview_extent_metadata_rules_test.dart
- opt_in_registration_test.dart
- plan_additional_rules_21_30_test.dart
- plan_additional_rules_31_40_test.dart
- prefer_overflow_bar_over_button_bar_rule_test.dart
- progress_tracker_dedup_test.dart
- project_info_root_uri_test.dart
- pubspec_lock_resolver_test.dart
- report_consolidator_test.dart
- require_data_encryption_pin_pattern_test.dart
- require_error_case_tests_test.dart
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
- violation_export_test.dart
- violation_parser_test.dart
- window_postmessage_scheduling_args_test.dart

## Recommended Approach

Replacing 3,530 stubs is a large effort. Prioritize by:

1. **Essential-tier rules first** — these run on every project and must work.
2. **Rules with known bugs** — `avoid_global_state` has open bug reports and stub tests.
3. **Rules with quick fixes** — quick fixes can silently break; test coverage is more critical.
4. **Highest stub-count files** — batch replacements in ios_rules, code_quality_rules, etc.

Each stub replacement requires:
- A fixture file in the appropriate `example*/lib/` directory (or extending an existing one)
- Assertions against actual rule analysis output (violation count, rule name, line number)
- Both positive (SHOULD trigger) and negative (should NOT trigger) cases
