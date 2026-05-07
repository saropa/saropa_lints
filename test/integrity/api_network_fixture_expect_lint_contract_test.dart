// Integrity: every api_network rule stays wired to a fixture that documents at least one BAD case.
library;

import 'dart:io';

import 'package:test/test.dart';

/// Contract: each listed rule has an `example/lib/api_network/` fixture that
/// declares `expect_lint:` for that rule (workstream 3 / plan §9 api_network).
void main() {
  // Tuple list mirrors the published rule set; update when adding/removing api_network rules.
  const cases = <({String rule, String fixturePath})>[
    (
      rule: 'avoid_cached_image_in_build',
      fixturePath:
          'example/lib/api_network/avoid_cached_image_in_build_fixture.dart',
    ),
    (
      rule: 'avoid_hardcoded_api_urls',
      fixturePath:
          'example/lib/api_network/avoid_hardcoded_api_urls_fixture.dart',
    ),
    (
      rule: 'avoid_over_fetching',
      fixturePath: 'example/lib/api_network/avoid_over_fetching_fixture.dart',
    ),
    (
      rule: 'avoid_redundant_requests',
      fixturePath:
          'example/lib/api_network/avoid_redundant_requests_fixture.dart',
    ),
    (
      rule: 'prefer_api_pagination',
      fixturePath: 'example/lib/api_network/prefer_api_pagination_fixture.dart',
    ),
    (
      rule: 'prefer_http_connection_reuse',
      fixturePath:
          'example/lib/api_network/prefer_http_connection_reuse_fixture.dart',
    ),
    (
      rule: 'prefer_streaming_response',
      fixturePath:
          'example/lib/api_network/prefer_streaming_response_fixture.dart',
    ),
    (
      rule: 'require_analytics_event_naming',
      fixturePath:
          'example/lib/api_network/require_analytics_event_naming_fixture.dart',
    ),
    (
      rule: 'require_content_type_check',
      fixturePath:
          'example/lib/api_network/require_content_type_check_fixture.dart',
    ),
    (
      rule: 'require_geolocator_timeout',
      fixturePath:
          'example/lib/api_network/require_geolocator_timeout_fixture.dart',
    ),
    (
      rule: 'require_http_status_check',
      fixturePath:
          'example/lib/api_network/require_http_status_check_fixture.dart',
    ),
    (
      rule: 'require_image_picker_error_handling',
      fixturePath:
          'example/lib/api_network/require_image_picker_error_handling_fixture.dart',
    ),
    (
      rule: 'require_image_picker_result_handling',
      fixturePath:
          'example/lib/api_network/require_image_picker_result_handling_fixture.dart',
    ),
    (
      rule: 'require_image_picker_source_choice',
      fixturePath:
          'example/lib/api_network/require_image_picker_source_choice_fixture.dart',
    ),
    (
      rule: 'require_notification_handler_top_level',
      fixturePath:
          'example/lib/api_network/require_notification_handler_top_level_fixture.dart',
    ),
    (
      rule: 'require_notification_permission_android13',
      fixturePath:
          'example/lib/api_network/require_notification_permission_android13_fixture.dart',
    ),
    (
      rule: 'require_offline_indicator',
      fixturePath:
          'example/lib/api_network/require_offline_indicator_fixture.dart',
    ),
    (
      rule: 'require_permission_denied_handling',
      fixturePath:
          'example/lib/api_network/require_permission_denied_handling_fixture.dart',
    ),
    (
      rule: 'require_permission_rationale',
      fixturePath:
          'example/lib/api_network/require_permission_rationale_fixture.dart',
    ),
    (
      rule: 'require_permission_status_check',
      fixturePath:
          'example/lib/api_network/require_permission_status_check_fixture.dart',
    ),
    (
      rule: 'require_request_timeout',
      fixturePath:
          'example/lib/api_network/require_request_timeout_fixture.dart',
    ),
    (
      rule: 'require_response_caching',
      fixturePath:
          'example/lib/api_network/require_response_caching_fixture.dart',
    ),
    (
      rule: 'require_retry_logic',
      fixturePath: 'example/lib/api_network/require_retry_logic_fixture.dart',
    ),
    (
      rule: 'require_sqflite_migration',
      fixturePath:
          'example/lib/api_network/require_sqflite_migration_fixture.dart',
    ),
    (
      rule: 'require_typed_api_response',
      fixturePath:
          'example/lib/api_network/require_typed_api_response_fixture.dart',
    ),
  ];

  group('api_network fixture expect_lint contracts', () {
    for (final c in cases) {
      test('${c.rule} declares expect_lint in ${c.fixturePath}', () {
        final file = File(c.fixturePath);
        expect(
          file.existsSync(),
          isTrue,
          reason: 'Missing fixture for ${c.rule}',
        );
        final body = file.readAsStringSync();
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
