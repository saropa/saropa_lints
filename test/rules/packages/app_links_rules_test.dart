import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/app_links_rules.dart';

/// Tests for app_links lint rules:
///   - 3 always-on best-practice / safety rules
///   - 3 version-gated migration rules (pack: app_links_6, gate: < 6.0.0)
///
/// Migration rules carry no fixture (matching the local_auth_3 exemplar): their
/// BAD example references symbols removed in v6, which do not resolve on a v6
/// project and would not fire under the pack gate. Fixtures cover the always-on
/// rules only.
///
/// Test fixtures: example_packages/lib/app_links/*
void main() {
  group('App Links Rules - Rule Instantiation', () {
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
      'AppLinksListenInBuildRule',
      'app_links_listen_in_build',
      () => AppLinksListenInBuildRule(),
    );
    testRule(
      'AppLinksUncaughtStreamErrorRule',
      'app_links_uncaught_stream_error',
      () => AppLinksUncaughtStreamErrorRule(),
    );
    testRule(
      'AppLinksAvoidGetInitialLinkStringRule',
      'app_links_avoid_get_initial_link_string',
      () => AppLinksAvoidGetInitialLinkStringRule(),
    );

    // Migration rules (app_links_6 pack, gate: app_links < 6.0.0).
    testRule(
      'AppLinksUseGetInitialLinkRule',
      'app_links_use_get_initial_link',
      () => AppLinksUseGetInitialLinkRule(),
    );
    testRule(
      'AppLinksUseGetLatestLinkRule',
      'app_links_use_get_latest_link',
      () => AppLinksUseGetLatestLinkRule(),
    );
    testRule(
      'AppLinksUseUriLinkStreamRule',
      'app_links_use_uri_link_stream',
      () => AppLinksUseUriLinkStreamRule(),
    );
  });

  group('App Links Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/app_links');

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
          'example_packages/lib/app_links/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });
}
