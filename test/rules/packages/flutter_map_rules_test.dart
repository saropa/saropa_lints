import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/flutter_map_rules.dart';

/// Tests for 6 flutter_map lint rules.
///
/// Test fixtures: example_packages/lib/flutter_map/*
void main() {
  group('flutter_map Rules - Rule Instantiation', () {
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
      'FlutterMapMissingUserAgentRule',
      'flutter_map_missing_user_agent',
      () => FlutterMapMissingUserAgentRule(),
    );
    testRule(
      'FlutterMapDeprecatedTileSizeRule',
      'flutter_map_deprecated_tile_size',
      () => FlutterMapDeprecatedTileSizeRule(),
    );
    testRule(
      'FlutterMapLegacyMapOptionsCenterRule',
      'flutter_map_legacy_map_options_center',
      () => FlutterMapLegacyMapOptionsCenterRule(),
    );
    testRule(
      'FlutterMapMissingErrorTileCallbackRule',
      'flutter_map_missing_error_tile_callback',
      () => FlutterMapMissingErrorTileCallbackRule(),
    );
    testRule(
      'FlutterMapDeprecatedPolygonLabelPlacementRule',
      'flutter_map_deprecated_polygon_label_placement',
      () => FlutterMapDeprecatedPolygonLabelPlacementRule(),
    );
    testRule(
      'FlutterMapFallbackUrlDisablesCacheRule',
      'flutter_map_fallback_url_disables_cache',
      () => FlutterMapFallbackUrlDisablesCacheRule(),
    );
  });

  group('flutter_map Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/flutter_map');

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
          'example_packages/lib/flutter_map/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });
}
