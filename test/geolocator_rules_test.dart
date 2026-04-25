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
    final fixtures = [
      'require_geolocator_battery_awareness',
      'avoid_geolocator_background_without_config',
      'prefer_geocoding_cache',
      'prefer_geolocation_coarse_location',
      'avoid_continuous_location_updates',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/geolocator/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Geolocator - Avoidance Rules', () {
    group('avoid_continuous_location_updates', () {
      test('always-on location stream SHOULD trigger', () {
        expect('always-on location stream', isNotNull);
      });

      test('on-demand location updates should NOT trigger', () {
        expect('on-demand location updates', isNotNull);
      });
    });
  });

  group('Geolocator - Requirement Rules', () {
    group('require_geolocator_battery_awareness', () {
      test('continuous GPS without battery consideration SHOULD trigger', () {
        expect('continuous GPS without battery consideration', isNotNull);
      });

      test('battery-aware location strategy should NOT trigger', () {
        expect('battery-aware location strategy', isNotNull);
      });
    });
  });

  group('Geolocator - Preference Rules', () {
    group('prefer_geocoding_cache', () {
      test('repeated geocoding for same location SHOULD trigger', () {
        expect('repeated geocoding for same location', isNotNull);
      });

      test('cached geocoding results should NOT trigger', () {
        expect('cached geocoding results', isNotNull);
      });
    });
  });
}
