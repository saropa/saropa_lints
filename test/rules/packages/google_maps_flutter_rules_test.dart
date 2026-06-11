import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/google_maps_flutter_rules.dart';

/// Tests for 6 google_maps_flutter lint rules.
///
/// Test fixtures: example_packages/lib/google_maps_flutter/*
void main() {
  group('Google Maps Flutter Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.lowerCaseName, codeName);
        expect(rule.code.problemMessage, contains('[$codeName]'));
        expect(rule.code.problemMessage.length, greaterThan(200));
        expect(rule.code.correctionMessage, isNotNull);
      });
    }

    testRule(
      'GoogleMapsMarkersRebuiltInBuildRule',
      'google_maps_markers_rebuilt_in_build',
      () => GoogleMapsMarkersRebuiltInBuildRule(),
    );
    testRule(
      'GoogleMapsCloudMapIdDeprecatedRule',
      'google_maps_cloud_map_id_deprecated',
      () => GoogleMapsCloudMapIdDeprecatedRule(),
    );
    testRule(
      'GoogleMapsSetMapStyleDeprecatedRule',
      'google_maps_set_map_style_deprecated',
      () => GoogleMapsSetMapStyleDeprecatedRule(),
    );
    testRule(
      'GoogleMapsBitmapDescriptorInBuildRule',
      'google_maps_bitmap_descriptor_in_build',
      () => GoogleMapsBitmapDescriptorInBuildRule(),
    );
    testRule(
      'GoogleMapsUnknownMapIdErrorUncheckedRule',
      'google_maps_unknown_map_id_error_unchecked',
      () => GoogleMapsUnknownMapIdErrorUncheckedRule(),
    );
    testRule(
      'GoogleMapsAnimateCameraInBuildRule',
      'google_maps_animate_camera_in_build',
      () => GoogleMapsAnimateCameraInBuildRule(),
    );
  });

  group('Google Maps Flutter Rules - Fixture Verification', () {
    final fixtures = [
      'google_maps_markers_rebuilt_in_build',
      'google_maps_cloud_map_id_deprecated',
      'google_maps_set_map_style_deprecated',
      'google_maps_bitmap_descriptor_in_build',
      'google_maps_unknown_map_id_error_unchecked',
      'google_maps_animate_camera_in_build',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/google_maps_flutter/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });
}
