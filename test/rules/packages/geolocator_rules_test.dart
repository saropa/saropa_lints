import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/geolocator_rules.dart';

/// Tests for 3 Geolocator lint rules.
///
/// Test fixtures: example_packages/lib/geolocator/*
void main() {
  group('Geolocator Rules - Rule Instantiation', () {
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
      'RequireGeolocatorBatteryAwarenessRule',
      'require_geolocator_battery_awareness',
      () => RequireGeolocatorBatteryAwarenessRule(),
    );

    testRule(
      'AvoidGeolocatorBackgroundWithoutConfigRule',
      'avoid_geolocator_background_without_config',
      () => AvoidGeolocatorBackgroundWithoutConfigRule(),
    );

    testRule(
      'PreferGeocodingCacheRule',
      'prefer_geocoding_cache',
      () => PreferGeocodingCacheRule(),
    );

    testRule(
      'AvoidContinuousLocationUpdatesRule',
      'avoid_continuous_location_updates',
      () => AvoidContinuousLocationUpdatesRule(),
    );

    testRule(
      'PreferGeolocationCoarseLocationRule',
      'prefer_geolocation_coarse_location',
      () => PreferGeolocationCoarseLocationRule(),
    );
  });

  group('Geolocator Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/geolocator');

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
        final file = File(
          'example_packages/lib/geolocator/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });
}
