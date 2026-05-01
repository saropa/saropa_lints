import 'dart:io';

import 'package:test/test.dart';

/// Tests for false positive fixes
///
/// This test file documents the expected behavior for rule fixes:
/// 1. require_subscription_status_check - word boundary matching
/// 2. require_deep_link_fallback - utility getter filtering
/// 3. require_https_only - safe replacement pattern detection
/// 4. avoid_passing_self_as_argument - literal value exclusion
/// 5. avoid_variable_shadowing - sibling closure scoping
/// 6. avoid_isar_clear_in_production - receiver type checking
/// 7. avoid_unused_instances - fire-and-forget constructor allowlist
/// 8. prefer_late_final - method call-site awareness
/// 9. avoid_nested_assignments - for-loop update clause and arrow body exclusion
/// 10. .contains() reduction (2026-03-01) - typeName/bodySource/targetSource
///     checks use word-boundary RegExp or exact sets so substrings do not trigger.
/// 11. History integration batch 37–61 - avoid_positioned_outside_stack (builder/
///     assignment/build root), avoid_single_child_column_row (IfElement/ForElement),
///     avoid_static_state (immutable static), avoid_stream_subscription_in_field
///     (listen as arg), avoid_string_concatenation_l10n (numeric-only),
///     avoid_unbounded_listview_in_column (overlay callbacks), avoid_unmarked_public_class
///     (private constructors), avoid_unnecessary_setstate (closure callbacks),
///     avoid_url_launcher_simulator_tests (import+API), check_mounted_after_async (guard clause).
/// 12. History integration batch 62–86 - function_always_returns_null (generators),
///     no_empty_string (idiom), no_equal_conditions (if-case), prefer_cached_getter,
///     prefer_compute_for_heavy_work, prefer_const_widgets_in_lists, prefer_edgeinsets_symmetric,
///     prefer_implicit_boolean_comparison, prefer_keep_alive, prefer_match_file_name,
///     prefer_no_commented_out_code, prefer_prefixed_global_constants, prefer_secure_random,
///     prefer_setup_teardown, prefer_static_method, prefer_stream_distinct.
/// 13. History integration batch 87–105 + rule_bugs 1–7 - prefer_switch_expression (complex case),
///     prefer_trailing_comma_always, prefer_unique_test_names, prefer_wheretype (negated),
///     require_currency_code_with_amount, require_dispose_pattern, require_envied_obfuscation,
///     require_error_case_tests, require_file_path_sanitization, require_hero_tag_uniqueness,
///     require_https_only_test, require_intl_currency_format, require_ios_callkit,
///     require_list_preallocate, require_location_timeout, require_number_format_locale,
///     string_contains_audit; rule_bugs: avoid_empty_setstate, avoid_expanded_outside_flex,
///     avoid_large_list_copy, avoid_long_parameter_list, conflicting_rules, dartdoc.
/// 14. History integration rule_bugs 8–22 - detect_unsorted_imports, duplicate_rules_async,
///     function_always_returns_null generator guard, no_magic_*_in_tests severity,
///     prefer_catch_over_on reverse, prefer_expanded_at_call_site, prefer_static_class abstract,
///     quick_fixes vscode, report_* (deprecated_usage crashes, duplicate paths, session,
///     violation dedup), require_minimum_contrast ignore, require_yield_between_db_awaits,
///     yield description and quickfix.
/// 15. use_existing_variable - same-source initializers that contain method/function
///     invocations are excluded (e.g. nextDouble(), DateTime.now()) so same source is
///     not treated as same value.
/// 16. avoid_stream_subscription_in_field - FunctionExpression closure boundary in
///     first parent-walk loop prevents cross-scope suppression (conditional listen
///     false positive, bare listen inside closure false negative).
///
/// Test fixtures are located in:
/// - example/lib/require_subscription_status_check_example.dart
/// - example/lib/navigation/require_deep_link_fallback_fixture.dart
/// - example/lib/security/require_https_only_fixture.dart
/// - example/lib/avoid_variable_shadowing_fixture.dart
/// - example_packages/lib/isar/avoid_isar_clear_in_production_fixture.dart
/// - example/lib/avoid_nested_assignments_fixture.dart
void main() {
  // Stub-only behavior tests were removed from this file. Keep fixture coverage
  // checks while real analyzer-backed assertions are added in targeted tests.

  group('Test Fixture Coverage', () {
    void expectFixtureExists(String path) {
      expect(
        File(path).existsSync(),
        isTrue,
        reason: 'Expected fixture to exist: $path',
      );
    }

    test('require_subscription_status_check has test fixture', () {
      // Located at: example/lib/require_subscription_status_check_example.dart
      expectFixtureExists(
        'example/lib/require_subscription_status_check_example.dart',
      );
    });

    test('require_deep_link_fallback has test fixture', () {
      // Located at: example/lib/navigation/require_deep_link_fallback_fixture.dart
      expectFixtureExists(
        'example/lib/navigation/require_deep_link_fallback_fixture.dart',
      );
    });

    test('require_https_only has test fixture', () {
      // Located at: example/lib/security/require_https_only_fixture.dart
      expectFixtureExists(
        'example/lib/security/require_https_only_fixture.dart',
      );
    });

    test('avoid_variable_shadowing has test fixture', () {
      // Located at: example/lib/avoid_variable_shadowing_fixture.dart
      expectFixtureExists('example/lib/avoid_variable_shadowing_fixture.dart');
    });

    test('avoid_isar_clear_in_production has test fixture', () {
      // Located at: example_packages/lib/isar/avoid_isar_clear_in_production_fixture.dart
      expectFixtureExists(
        'example_packages/lib/isar/avoid_isar_clear_in_production_fixture.dart',
      );
    });

    test('prefer_late_final has test fixture', () {
      // Located at: example/lib/code_quality/code_quality_fixture.dart
      expectFixtureExists('example/lib/code_quality/code_quality_fixture.dart');
    });

    test('avoid_nested_assignments has test fixture', () {
      // Located at: example/lib/avoid_nested_assignments_fixture.dart
      expectFixtureExists('example/lib/avoid_nested_assignments_fixture.dart');
    });

    test('require_websocket_reconnection has mock stubs', () {
      // Located at: example/lib/flutter_mocks.dart (WebSocket, WebSocketChannel)
      // Fixture at: example/lib/async/async_rules_fixture.dart
      expectFixtureExists('example/lib/flutter_mocks.dart');
      expectFixtureExists('example/lib/async/async_rules_fixture.dart');
    });

    test('prefer_wheretype_over_where_is has test fixture', () {
      // Located at: example/lib/stylistic_null_collection/prefer_wheretype_over_where_is_fixture.dart
      expectFixtureExists(
        'example/lib/stylistic_null_collection/prefer_wheretype_over_where_is_fixture.dart',
      );
    });

    test('6.0.4 avoid_dynamic_sql has regression fixture', () {
      // example/lib/security/avoid_dynamic_sql_fixture.dart (PRAGMA, word-boundary)
      expectFixtureExists(
        'example/lib/security/avoid_dynamic_sql_fixture.dart',
      );
    });

    test('6.0.4 avoid_path_traversal has regression fixture', () {
      // example/lib/security/avoid_path_traversal_fixture.dart (private helper)
      expectFixtureExists(
        'example/lib/security/avoid_path_traversal_fixture.dart',
      );
    });

    test(
      'avoid_screenshot_sensitive has regression fixture (debug/viewer, fromsettings)',
      () {
        // example/lib/security/avoid_screenshot_sensitive_fixture.dart
        // Debug/tooling (viewer, webview) and WebViewScreenFromSettings must NOT trigger
        expectFixtureExists(
          'example/lib/security/avoid_screenshot_sensitive_fixture.dart',
        );
      },
    );

    test('6.0.4 require_file_path_sanitization has regression fixture', () {
      // example/lib/file_handling/require_file_path_sanitization_fixture.dart
      expectFixtureExists(
        'example/lib/file_handling/require_file_path_sanitization_fixture.dart',
      );
    });

    test('6.0.4 avoid_unsafe_reduce has regression fixture', () {
      // example/lib/collections/avoid_unsafe_reduce_fixture.dart (guarded reduce)
      expectFixtureExists(
        'example/lib/collections/avoid_unsafe_reduce_fixture.dart',
      );
    });

    test('6.0.4 require_search_debounce has regression fixture', () {
      // example/lib/ui_ux/require_search_debounce_fixture.dart (class field debouncer)
      expectFixtureExists(
        'example/lib/ui_ux/require_search_debounce_fixture.dart',
      );
    });

    test('6.0.4 require_minimum_contrast has regression fixture', () {
      // example/lib/accessibility/require_minimum_contrast_fixture.dart (unresolvable bg)
      expectFixtureExists(
        'example/lib/accessibility/require_minimum_contrast_fixture.dart',
      );
    });
  });
}
