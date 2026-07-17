import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/url_launcher_rules.dart';

/// Tests for 3 URL launcher lint rules.
///
/// These rules cover launch pre-checks, fallback handling, and simulator
/// test safety for the url_launcher package.
///
/// Test fixtures: example_packages/lib/url_launcher/*
void main() {
  group('Url Launcher Rules - Rule Instantiation', () {
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
      'RequireUrlLauncherCanLaunchCheckRule',
      'require_url_launcher_can_launch_check',
      () => RequireUrlLauncherCanLaunchCheckRule(),
    );

    testRule(
      'AvoidUrlLauncherSimulatorTestsRule',
      'avoid_url_launcher_simulator_tests',
      () => AvoidUrlLauncherSimulatorTestsRule(),
    );

    testRule(
      'PreferUrlLauncherFallbackRule',
      'prefer_url_launcher_fallback',
      () => PreferUrlLauncherFallbackRule(),
    );
  });

  group('URL Launcher Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/url_launcher');

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
          'example_packages/lib/url_launcher/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });
}
