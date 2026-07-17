import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/resources/resource_management_rules.dart';

/// Tests for 14 Resource Management lint rules.
///
/// Test fixtures: example/lib/resource_management/*
void main() {
  group('Resource Management Rules - Rule Instantiation', () {
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
      'RequireFileCloseInFinallyRule',
      'require_file_close_in_finally',
      () => RequireFileCloseInFinallyRule(),
    );

    testRule(
      'RequireDatabaseCloseRule',
      'require_database_close',
      () => RequireDatabaseCloseRule(),
    );

    testRule(
      'RequireHttpClientCloseRule',
      'require_http_client_close',
      () => RequireHttpClientCloseRule(),
    );

    testRule(
      'RequireNativeResourceCleanupRule',
      'require_native_resource_cleanup',
      () => RequireNativeResourceCleanupRule(),
    );

    testRule(
      'RequireWebSocketCloseRule',
      'require_websocket_close',
      () => RequireWebSocketCloseRule(),
    );

    testRule(
      'RequirePlatformChannelCleanupRule',
      'require_platform_channel_cleanup',
      () => RequirePlatformChannelCleanupRule(),
    );

    testRule(
      'RequireIsolateKillRule',
      'require_isolate_kill',
      () => RequireIsolateKillRule(),
    );

    testRule(
      'RequireCameraDisposeRule',
      'require_camera_dispose',
      () => RequireCameraDisposeRule(),
    );

    testRule(
      'RequireImageCompressionRule',
      'require_image_compression',
      () => RequireImageCompressionRule(),
    );

    testRule(
      'PreferCoarseLocationRule',
      'prefer_coarse_location_when_sufficient',
      () => PreferCoarseLocationRule(),
    );

    testRule(
      'AvoidImagePickerWithoutSourceRule',
      'avoid_image_picker_without_source',
      () => AvoidImagePickerWithoutSourceRule(),
    );

    testRule(
      'PreferGeolocatorAccuracyAppropriateRule',
      'prefer_geolocator_accuracy_appropriate',
      () => PreferGeolocatorAccuracyAppropriateRule(),
    );

    testRule(
      'PreferGeolocatorLastKnownRule',
      'prefer_geolocator_last_known',
      () => PreferGeolocatorLastKnownRule(),
    );

    testRule(
      'PreferImagePickerMultiSelectionRule',
      'prefer_image_picker_multi_selection',
      () => PreferImagePickerMultiSelectionRule(),
    );
  });

  group('Resource Management Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/resource_management');

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
      test('$fixture fixture exists', () {
        final file = File(
          'example/lib/resource_management/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture verification while migrating to analyzer-backed behavior tests.
}
