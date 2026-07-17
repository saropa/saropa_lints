import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/cached_network_image_rules.dart';

/// Tests for 3 cached_network_image lint rules (provider-form + inline manager).
///
/// Test fixtures: example_packages/lib/cached_network_image/*
void main() {
  group('CachedNetworkImage Rules - Rule Instantiation', () {
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
      'RequireCachedImageProviderDimensionsRule',
      'require_cached_image_provider_dimensions',
      () => RequireCachedImageProviderDimensionsRule(),
    );
    testRule(
      'RequireCachedImageProviderErrorListenerRule',
      'require_cached_image_provider_error_listener',
      () => RequireCachedImageProviderErrorListenerRule(),
    );
    testRule(
      'AvoidInlineCacheManagerConstructionRule',
      'avoid_inline_cache_manager_construction',
      () => AvoidInlineCacheManagerConstructionRule(),
    );
  });

  group('CachedNetworkImage Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/cached_network_image');

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
          'example_packages/lib/cached_network_image/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });
}
