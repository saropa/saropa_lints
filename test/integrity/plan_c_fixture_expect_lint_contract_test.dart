import 'dart:io';

import 'package:test/test.dart';

/// Contract: each rule listed in plan/TESTING_AND_RELEASE.md §10 C1-C24 has a
/// fixture file under example/lib/<category>/ that declares an
/// `// expect_lint: <rule>` marker. This is the "today" safety net for the
/// fixture_lint_integration_test additions, which only assert when
/// `dart run custom_lint` is reachable in the example package.
void main() {
  // Several rules share a fixture file (e.g. async_rules_fixture.dart,
  // disposal_rules_fixture.dart) — that is intentional and matches the
  // existing api_network contract pattern.
  const cases = <({String rule, String fixturePath})>[
    // C1-C10: async.
    (
      rule: 'avoid_future_ignore',
      fixturePath: 'example/lib/async/avoid_future_ignore_fixture.dart',
    ),
    (
      rule: 'avoid_future_in_build',
      fixturePath: 'example/lib/async/async_rules_fixture.dart',
    ),
    (
      rule: 'avoid_future_tostring',
      fixturePath: 'example/lib/async/avoid_future_tostring_fixture.dart',
    ),
    (
      rule: 'avoid_multiple_stream_listeners',
      fixturePath:
          'example/lib/async/avoid_multiple_stream_listeners_fixture.dart',
    ),
    (
      rule: 'avoid_nested_futures',
      fixturePath: 'example/lib/async/avoid_nested_futures_fixture.dart',
    ),
    (
      rule: 'avoid_redundant_async',
      fixturePath: 'example/lib/async/avoid_redundant_async_fixture.dart',
    ),
    (
      rule: 'avoid_sequential_awaits',
      fixturePath: 'example/lib/async/avoid_sequential_awaits_fixture.dart',
    ),
    (
      rule: 'avoid_stream_sync_events',
      fixturePath: 'example/lib/async/avoid_stream_sync_events_fixture.dart',
    ),
    (
      rule: 'avoid_stream_tostring',
      fixturePath: 'example/lib/async/avoid_stream_tostring_fixture.dart',
    ),
    (
      rule: 'avoid_sync_on_every_change',
      fixturePath: 'example/lib/async/avoid_sync_on_every_change_fixture.dart',
    ),
    // C11-C15: disposal.
    (
      rule: 'dispose_class_fields',
      fixturePath: 'example/lib/disposal/dispose_class_fields_fixture.dart',
    ),
    (
      rule: 'prefer_dispose_before_new_instance',
      fixturePath: 'example/lib/disposal/disposal_rules_fixture.dart',
    ),
    (
      rule: 'require_change_notifier_dispose',
      fixturePath:
          'example/lib/disposal/require_change_notifier_dispose_fixture.dart',
    ),
    (
      rule: 'require_text_editing_controller_dispose',
      fixturePath: 'example/lib/disposal/disposal_rules_fixture.dart',
    ),
    (
      rule: 'require_video_player_controller_dispose',
      fixturePath:
          'example/lib/disposal/require_video_player_controller_dispose_fixture.dart',
    ),
    // C16-C19: error_handling.
    (
      rule: 'avoid_swallowing_exceptions',
      fixturePath:
          'example/lib/error_handling/avoid_swallowing_exceptions_fixture.dart',
    ),
    (
      rule: 'avoid_generic_exceptions',
      fixturePath:
          'example/lib/error_handling/avoid_generic_exceptions_fixture.dart',
    ),
    (
      rule: 'prefer_result_pattern',
      fixturePath:
          'example/lib/error_handling/prefer_result_pattern_fixture.dart',
    ),
    (
      rule: 'require_app_startup_error_handling',
      fixturePath:
          'example/lib/error_handling/require_app_startup_error_handling_fixture.dart',
    ),
    // C20-C24: security.
    (
      rule: 'avoid_hardcoded_credentials',
      fixturePath:
          'example/lib/security/avoid_hardcoded_credentials_fixture.dart',
    ),
    (
      rule: 'avoid_token_in_url',
      fixturePath: 'example/lib/security/avoid_token_in_url_fixture.dart',
    ),
    (
      rule: 'avoid_path_traversal',
      fixturePath: 'example/lib/security/avoid_path_traversal_fixture.dart',
    ),
    (
      rule: 'avoid_jwt_decode_client',
      fixturePath: 'example/lib/security/avoid_jwt_decode_client_fixture.dart',
    ),
    (
      rule: 'prefer_local_auth',
      fixturePath: 'example/lib/security/prefer_local_auth_fixture.dart',
    ),
  ];

  group('Plan §10 C fixture expect_lint contracts', () {
    for (final c in cases) {
      test('${c.rule} declares expect_lint in ${c.fixturePath}', () {
        final file = File(c.fixturePath);
        expect(
          file.existsSync(),
          isTrue,
          reason: 'Missing fixture for ${c.rule}',
        );
        final body = file.readAsStringSync();
        // Word boundary: `\b` so `avoid_future_in_build` does not match
        // `avoid_future_in_builder` accidentally.
        final pattern = RegExp(
          r'//\s*expect_lint:\s*' + RegExp.escape(c.rule) + r'\b',
        );
        expect(
          pattern.hasMatch(body),
          isTrue,
          reason: 'Fixture should declare // expect_lint: ${c.rule}',
        );
      });
    }
  });
}
