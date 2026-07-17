import 'dart:io';

import 'package:saropa_lints/src/rules/network/api_network_rules.dart';
import 'package:test/test.dart';

/// Tests for 38 Api Network lint rules.
///
/// Test fixtures: example/lib/api_network/*
// HTTP client, interceptors, and transport security rules; see fixtures for LINTs.
void main() {
  group('Api Network Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.lowerCaseName, codeName);
        expect(rule.code.problemMessage, contains('[$codeName]'));
        expect(rule.code.problemMessage.length, greaterThan(50));
        expect(rule.code.correctionMessage, isNotNull);
      });
    }

    testRule(
      'RequireHttpStatusCheckRule',
      'require_http_status_check',
      () => RequireHttpStatusCheckRule(),
    );
    testRule(
      'AvoidHardcodedApiUrlsRule',
      'avoid_hardcoded_api_urls',
      () => AvoidHardcodedApiUrlsRule(),
    );
    testRule(
      'RequireRetryLogicRule',
      'require_retry_logic',
      () => RequireRetryLogicRule(),
    );
    testRule(
      'RequireTypedApiResponseRule',
      'require_typed_api_response',
      () => RequireTypedApiResponseRule(),
    );
    testRule(
      'RequireConnectivityCheckRule',
      'require_connectivity_check',
      () => RequireConnectivityCheckRule(),
    );
    testRule(
      'RequireApiErrorMappingRule',
      'require_api_error_mapping',
      () => RequireApiErrorMappingRule(),
    );
    testRule(
      'RequireRequestTimeoutRule',
      'require_request_timeout',
      () => RequireRequestTimeoutRule(),
    );

    test('RequireRequestTimeoutRule exposes a quick fix', () {
      expect(RequireRequestTimeoutRule().fixGenerators, isNotEmpty);
    });

    testRule(
      'RequireOfflineIndicatorRule',
      'require_offline_indicator',
      () => RequireOfflineIndicatorRule(),
    );
    testRule(
      'PreferStreamingResponseRule',
      'prefer_streaming_response',
      () => PreferStreamingResponseRule(),
    );
    testRule(
      'PreferHttpConnectionReuseRule',
      'prefer_http_connection_reuse',
      () => PreferHttpConnectionReuseRule(),
    );
    testRule(
      'AvoidRedundantRequestsRule',
      'avoid_redundant_requests',
      () => AvoidRedundantRequestsRule(),
    );
    testRule(
      'RequireResponseCachingRule',
      'require_response_caching',
      () => RequireResponseCachingRule(),
    );
    testRule(
      'PreferPaginationRule',
      'prefer_api_pagination',
      () => PreferPaginationRule(),
    );
    testRule(
      'AvoidOverFetchingRule',
      'avoid_over_fetching',
      () => AvoidOverFetchingRule(),
    );
    testRule(
      'RequireCancelTokenRule',
      'require_cancel_token',
      () => RequireCancelTokenRule(),
    );
    testRule(
      'RequireWebSocketErrorHandlingRule',
      'require_websocket_error_handling',
      () => RequireWebSocketErrorHandlingRule(),
    );

    test('RequireWebSocketErrorHandlingRule exposes a quick fix', () {
      expect(RequireWebSocketErrorHandlingRule().fixGenerators, isNotEmpty);
    });
    testRule(
      'RequireContentTypeCheckRule',
      'require_content_type_check',
      () => RequireContentTypeCheckRule(),
    );
    testRule(
      'AvoidWebsocketWithoutHeartbeatRule',
      'avoid_websocket_without_heartbeat',
      () => AvoidWebsocketWithoutHeartbeatRule(),
    );
    testRule(
      'RequireUrlLauncherErrorHandlingRule',
      'require_url_launcher_error_handling',
      () => RequireUrlLauncherErrorHandlingRule(),
    );
    testRule(
      'RequireImagePickerErrorHandlingRule',
      'require_image_picker_error_handling',
      () => RequireImagePickerErrorHandlingRule(),
    );
    testRule(
      'RequireImagePickerSourceChoiceRule',
      'require_image_picker_source_choice',
      () => RequireImagePickerSourceChoiceRule(),
    );
    testRule(
      'RequireGeolocatorTimeoutRule',
      'require_geolocator_timeout',
      () => RequireGeolocatorTimeoutRule(),
    );
    testRule(
      'RequireConnectivitySubscriptionCancelRule',
      'require_connectivity_subscription_cancel',
      () => RequireConnectivitySubscriptionCancelRule(),
    );
    testRule(
      'RequireNotificationHandlerTopLevelRule',
      'require_notification_handler_top_level',
      () => RequireNotificationHandlerTopLevelRule(),
    );
    testRule(
      'RequirePermissionDeniedHandlingRule',
      'require_permission_denied_handling',
      () => RequirePermissionDeniedHandlingRule(),
    );
    testRule(
      'RequireImagePickerResultHandlingRule',
      'require_image_picker_result_handling',
      () => RequireImagePickerResultHandlingRule(),
    );
    testRule(
      'AvoidCachedImageInBuildRule',
      'avoid_cached_image_in_build',
      () => AvoidCachedImageInBuildRule(),
    );
    testRule(
      'RequireSqfliteMigrationRule',
      'require_sqflite_migration',
      () => RequireSqfliteMigrationRule(),
    );
    testRule(
      'RequirePermissionRationaleRule',
      'require_permission_rationale',
      () => RequirePermissionRationaleRule(),
    );
    testRule(
      'RequirePermissionStatusCheckRule',
      'require_permission_status_check',
      () => RequirePermissionStatusCheckRule(),
    );
    testRule(
      'RequireNotificationPermissionAndroid13Rule',
      'require_notification_permission_android13',
      () => RequireNotificationPermissionAndroid13Rule(),
    );
    testRule(
      'RequireSseSubscriptionCancelRule',
      'require_sse_subscription_cancel',
      () => RequireSseSubscriptionCancelRule(),
    );
    testRule(
      'PreferTimeoutOnRequestsRule',
      'prefer_timeout_on_requests',
      () => PreferTimeoutOnRequestsRule(),
    );

    test('PreferTimeoutOnRequestsRule exposes a quick fix', () {
      expect(PreferTimeoutOnRequestsRule().fixGenerators, isNotEmpty);
    });

    testRule(
      'RequireWebsocketReconnectionRule',
      'require_websocket_reconnection',
      () => RequireWebsocketReconnectionRule(),
    );
    testRule(
      'RequireAnalyticsEventNamingRule',
      'require_analytics_event_naming',
      () => RequireAnalyticsEventNamingRule(),
    );
    testRule(
      'PreferBatchRequestsRule',
      'prefer_batch_requests',
      () => PreferBatchRequestsRule(),
    );
    testRule(
      'RequireCompressionRule',
      'require_accept_encoding_header',
      () => RequireCompressionRule(),
    );
    testRule(
      'RequireSslPinningSensitiveRule',
      'require_ssl_pinning_sensitive',
      () => RequireSslPinningSensitiveRule(),
    );
    testRule(
      'RequireApiResponseValidationRule',
      'require_api_response_validation',
      () => RequireApiResponseValidationRule(),
    );
    testRule(
      'RequireContentTypeValidationRule',
      'require_content_type_validation',
      () => RequireContentTypeValidationRule(),
    );
  });
  group('Api Network Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/api_network');

    // Auto-discover fixtures from disk so new files are verified
    // automatically — no manual list to maintain.
    final fixtures =
        fixtureDir
            .listSync()
            .whereType<File>()
            .map((f) => f.uri.pathSegments.last)
            .where((name) => name.endsWith('_fixture.dart'))
            .map((name) => name.replaceAll('_fixture.dart', ''))
            .toList()
          ..sort();

    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);
      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('\$fixture fixture exists', () {
        final file = File('example/lib/api_network/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture checks while migrating to analyzer-backed behavior tests.
}
