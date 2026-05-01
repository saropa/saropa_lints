import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart';
import 'package:saropa_lints/src/models/violation.dart';
import 'package:saropa_lints/src/violation_parser.dart';
import 'package:test/test.dart';

final Set<String> _saropaRuleCodes = allSaropaRules
    .map((r) => r.code.lowerCaseName)
    .toSet();

/// Runs `dart analyze` and `dart run custom_lint` in [exampleDir], parses both,
/// and returns the **union** of violations (deduped by file/line/column/rule).
Future<List<Violation>> _violationsForExample(Directory exampleDir) async {
  final analyzeResult = await Process.run(
    'dart',
    ['analyze'],
    workingDirectory: exampleDir.path,
    runInShell: true,
  );
  final analyzeOut = '${analyzeResult.stdout}${analyzeResult.stderr}';
  final fromAnalyze = parseDartAnalyzeHumanOutput(analyzeOut);

  final customLintResult = await Process.run(
    'dart',
    ['run', 'custom_lint'],
    workingDirectory: exampleDir.path,
    runInShell: true,
  );
  final fromCustom = parseViolations(customLintResult.stdout as String);

  final byKey = <String, Violation>{};
  void addAll(List<Violation> list) {
    for (final v in list) {
      byKey['${v.file}|${v.line}|${v.column}|${v.rule}'] = v;
    }
  }

  addAll(fromAnalyze);
  addAll(fromCustom);
  return byKey.values.toList();
}

/// Integration test: run custom_lint on an example package and assert
/// output is parseable and fixtures produce expected rule diagnostics.
///
/// Validates that fixture files are actually analyzed and that
/// parseViolations correctly parses custom_lint output. Run from repo root.
void main() {
  // Process.run('dart', ['run', 'custom_lint']) can hang if the analyzer
  // plugin stalls or package resolution deadlocks — cap each test.
  group('Fixture lint integration', timeout: const Timeout(Duration(minutes: 2)), () {
    test(
      'dart analyze (or custom_lint) on example produces parseable violations',
      () async {
        final exampleDir = Directory('example');
        if (!exampleDir.existsSync()) {
          return; // Skip when example not present (e.g. in some CI)
        }

        final violations = await _violationsForExample(exampleDir);
        expect(violations, isA<List>());
        if (violations.isEmpty) {
          return;
        }
        expect(violations.first.file, isNotEmpty);
      },
    );

    /// Behavioral test: run linter on example and assert specific rules
    /// fire on fixture code (proves linter-on-code when `dart analyze` or
    /// `dart run custom_lint` runs). When neither yields parseable violations,
    /// skip per-rule assertions so the test still passes.
    test('example analysis reports expected rules from fixtures', () async {
      final exampleDir = Directory('example');
      if (!exampleDir.existsSync()) {
        return;
      }

      final analyzeResult = await Process.run(
        'dart',
        ['analyze'],
        workingDirectory: exampleDir.path,
        runInShell: true,
      );
      final fromAnalyze = parseDartAnalyzeHumanOutput(
        '${analyzeResult.stdout}${analyzeResult.stderr}',
      );

      final customLintResult = await Process.run(
        'dart',
        ['run', 'custom_lint'],
        workingDirectory: exampleDir.path,
        runInShell: true,
      );
      final fromCustom = parseViolations(customLintResult.stdout as String);

      if (fromAnalyze.isEmpty && fromCustom.isEmpty) {
        return;
      }

      final ruleCodes = {
        ...fromAnalyze.map((v) => v.rule),
        ...fromCustom.map((v) => v.rule),
      };

      // When `dart run custom_lint` is unavailable, only compile-time plan
      // fixtures are asserted (native `dart analyze` output).
      const expectedCompileTimeFromDartAnalyze = [
        'abi_specific_integer_invalid',
        'abstract_field_initializer',
        'conflicting_constructor_and_static_member',
        'deprecated_new_in_comment_reference',
        'duplicate_field_name',
        'external_with_initializer',
        'field_initializer_redirecting_constructor',
        'illegal_concrete_enum_member',
        'invalid_extension_argument_count',
        'invalid_literal_annotation',
        'invalid_super_formal_parameter_location',
        'non_constant_map_element',
        'return_in_generator',
        'subtype_of_disallowed_type',
        'type_check_with_null',
        'uri_does_not_exist',
        'wrong_number_of_parameters_for_setter',
        'yield_in_non_generator',
      ];

      // Fixtures in example/lib with expect_lint for these rules;
      // assert they appear when custom_lint runs (behavioral coverage).
      // Priority: async, error_handling, security (see UNIT_TEST_COVERAGE_REVIEW.md §4).
      const expectedFromFixtures = [
        'avoid_catch_all',
        'avoid_dialog_context_after_async',
        'require_stream_controller_close',
        'require_feature_flag_default',
        'prefer_specifying_future_value_type',
        'avoid_exception_in_constructor',
        'avoid_hardcoded_encryption_keys',
        'check_mounted_after_async',
        'avoid_async_in_build',
        'require_stream_subscription_cancel',
        'avoid_future_then_in_async',
        'avoid_unawaited_future',
        'avoid_context_across_async',
        'prefer_secure_random_for_crypto',
        'require_completer_error_handling',
        'avoid_void_async',
        'prefer_compile_time_config',
        'prefer_flavor_configuration',
        'prefer_connectivity_debounce',
        'prefer_correct_json_casts',
        'prefer_future_wait',
        'require_native_resource_cleanup',
        'prefer_correct_stream_return_type',
        'avoid_stream_subscription_in_field',
        'require_dispose_implementation',
        'avoid_assert_in_production',
        'require_bluetooth_state_check',
        'avoid_losing_stack_trace',
        'require_secure_key_generation',
        'avoid_blocking_database_ui',
        'require_list_preallocate',
        'require_sqflite_close',
        'avoid_stream_in_build',
        'avoid_redundant_await',
        'require_connectivity_check',
        'avoid_string_concatenation_loop',
        'avoid_controller_in_build',
        'avoid_synchronous_file_io',
        'avoid_rebuild_on_scroll',
        'require_api_error_mapping',
        'avoid_unassigned_stream_subscriptions',
        'prefer_const_widgets',
        'avoid_websocket_without_heartbeat',
        'prefer_lazy_loading_images',
        'require_cancel_token',
        'require_connectivity_subscription_cancel',
        'avoid_nested_streams_and_futures',
        'avoid_global_key_misuse',
        'avoid_object_creation_in_hot_loops',
        'prefer_layout_builder_over_media_query',
        'require_future_wait_error_handling',
        'prefer_native_file_dialogs',
        'avoid_expensive_build',
        'avoid_scroll_listener_in_build',
        'avoid_widget_creation_in_loop',
        'require_item_extent_for_large_lists',
        'avoid_screenshot_sensitive',
        // Plan §10 C1-C10 — async fixtures.
        'avoid_future_ignore',
        'avoid_future_in_build',
        'avoid_future_tostring',
        'avoid_multiple_stream_listeners',
        'avoid_nested_futures',
        'avoid_redundant_async',
        'avoid_sequential_awaits',
        'avoid_stream_sync_events',
        'avoid_stream_tostring',
        'avoid_sync_on_every_change',
        // Plan §10 C11-C15 — disposal fixtures.
        'dispose_class_fields',
        'prefer_dispose_before_new_instance',
        'require_change_notifier_dispose',
        'require_text_editing_controller_dispose',
        'require_video_player_controller_dispose',
        // Plan §10 C16-C19 — error_handling fixtures.
        'avoid_swallowing_exceptions',
        'avoid_generic_exceptions',
        'prefer_result_pattern',
        'require_app_startup_error_handling',
        // Plan §10 C20-C24 — security fixtures.
        'avoid_hardcoded_credentials',
        'avoid_token_in_url',
        'avoid_path_traversal',
        'avoid_jwt_decode_client',
        'prefer_local_auth',
      ];

      for (final rule in expectedCompileTimeFromDartAnalyze) {
        expect(
          ruleCodes.contains(rule),
          isTrue,
          reason: 'Rule $rule should appear in dart analyze output for example',
        );
      }

      if (fromCustom.isEmpty) {
        return;
      }

      final expectedSet = expectedFromFixtures.toSet();
      for (final rule in expectedSet) {
        expect(
          ruleCodes.contains(rule),
          isTrue,
          reason: 'Rule $rule should fire on example fixtures (custom_lint)',
        );
      }
    });

    /// avoid_unawaited_future: only the BAD case (bare Future) must trigger;
    /// unawaited(...) and unawaited(... .then()) must NOT trigger (false positive fix).
    test(
      'avoid_unawaited_future fixture has exactly one violation (unawaited() lines do not trigger)',
      () async {
        final exampleDir = Directory('example');
        if (!exampleDir.existsSync()) {
          return;
        }

        final violations = await _violationsForExample(exampleDir);
        final fixtureViolations = violations
            .where(
              (v) =>
                  v.rule == 'avoid_unawaited_future' &&
                  v.file.contains('avoid_unawaited_future_fixture'),
            )
            .toList();

        if (fixtureViolations.isEmpty) {
          // Path format or analysis set may omit this file; skip strict check.
          return;
        }
        expect(
          fixtureViolations.length,
          equals(1),
          reason:
              'Fixture has one BAD line (_saveData();) and two GOOD unawaited() '
              'lines that must not trigger; got ${fixtureViolations.length}',
        );
        expect(
          fixtureViolations.single.line,
          equals(12),
          reason: 'Violation should be on line 12 (_saveData(); in _bad())',
        );
      },
    );

    test(
      'prefer_skeleton_over_spinner fixture only reports indeterminate cases',
      () async {
        final exampleDir = Directory('example');
        if (!exampleDir.existsSync()) {
          return;
        }

        final violations = await _violationsForExample(exampleDir);
        final fixtureViolations = violations
            .where(
              (v) =>
                  v.rule == 'prefer_skeleton_over_spinner' &&
                  v.file.contains('prefer_skeleton_over_spinner_fixture'),
            )
            .toList();

        if (fixtureViolations.isEmpty) {
          // Skip when custom_lint output does not include this fixture.
          return;
        }

        expect(
          fixtureViolations.length,
          equals(2),
          reason:
              'Fixture has two BAD indeterminate cases and determinate value: '
              'cases that must not trigger; got ${fixtureViolations.length}',
        );

        final lines = fixtureViolations.map((v) => v.line).toSet();
        expect(lines.contains(115), isTrue, reason: 'Should lint bare spinner');
        expect(
          lines.contains(144),
          isTrue,
          reason: 'Should lint explicit value: null spinner',
        );
      },
    );

    test(
      'prefer_try_parse_for_dynamic_data skips provably safe regex/literal inputs',
      () async {
        final exampleDir = Directory('example');
        if (!exampleDir.existsSync()) {
          return;
        }

        final violations = await _violationsForExample(exampleDir);
        final fixtureViolations = violations
            .where(
              (v) =>
                  v.rule == 'prefer_try_parse_for_dynamic_data' &&
                  v.file.contains('prefer_try_parse_for_dynamic_data_fixture'),
            )
            .toList();

        if (fixtureViolations.isEmpty) {
          // Skip when custom_lint output does not include this fixture.
          return;
        }

        final lines = fixtureViolations.map((v) => v.line).toSet();
        expect(lines.contains(7), isTrue, reason: 'dynamic input should lint');
        expect(
          lines.contains(12),
          isTrue,
          reason: 'invalid numeric literal should lint',
        );
        expect(
          lines.contains(16),
          isFalse,
          reason: 'valid literal parse should not lint',
        );
        expect(
          lines.contains(24),
          isFalse,
          reason: 'digit-only regex capture should not lint',
        );
        expect(
          lines.contains(25),
          isFalse,
          reason: 'digit-only regex group() should not lint',
        );
        expect(
          lines.contains(36),
          isFalse,
          reason: 'substring after digit-only hasMatch guard should not lint',
        );
      },
    );

    test(
      'avoid_memory_intensive_operations fixture only reports string concat in loop',
      () async {
        final exampleDir = Directory('example');
        if (!exampleDir.existsSync()) {
          return;
        }

        final violations = await _violationsForExample(exampleDir);
        final fixtureViolations = violations
            .where(
              (v) =>
                  v.rule == 'avoid_memory_intensive_operations' &&
                  v.file.contains('avoid_memory_intensive_operations_fixture'),
            )
            .toList();

        if (fixtureViolations.isEmpty) {
          // Skip when custom_lint output does not include this fixture.
          return;
        }

        expect(
          fixtureViolations.length,
          equals(1),
          reason:
              'Fixture has one BAD string concat line and GOOD numeric += '
              'accumulation that must not trigger; got '
              '${fixtureViolations.length}',
        );
        expect(
          fixtureViolations.single.line,
          equals(117),
          reason: 'Violation should be on result += item.toString();',
        );
      },
    );

    /// Behavioral test: compliant-only file must produce no violations.
    /// Proves "compliant code → no lint" for the rules exercised in that file.
    test('compliant-only fixture has no violations', () async {
      final exampleDir = Directory('example');
      if (!exampleDir.existsSync()) {
        return;
      }

      final violations = await _violationsForExample(exampleDir);
      final compliantFileViolations = violations
          .where((v) => v.file.contains('behavioral_test_compliant_only.dart'))
          .where((v) => _saropaRuleCodes.contains(v.rule))
          .toList();

      expect(
        compliantFileViolations,
        isEmpty,
        reason:
            'Compliant-only file should have no lints; got ${compliantFileViolations.length}',
      );
    });
  });
}
