import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/media/media_rules.dart';

/// Tests for 3 Media lint rules.
///
/// Test fixtures: example/lib/media/*
void main() {
  group('Media Rules - Rule Instantiation', () {
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
      'AvoidAutoplayAudioRule',
      'avoid_autoplay_audio',
      () => AvoidAutoplayAudioRule(),
    );

    testRule(
      'PreferCameraResolutionSelectionRule',
      'prefer_camera_resolution_selection',
      () => PreferCameraResolutionSelectionRule(),
    );

    testRule(
      'PreferAudioSessionConfigRule',
      'prefer_audio_session_config',
      () => PreferAudioSessionConfigRule(),
    );

    testRule(
      'AvoidAudioInBackgroundWithoutConfigRule',
      'avoid_audio_in_background_without_config',
      () => AvoidAudioInBackgroundWithoutConfigRule(),
    );
  });

  group('Media Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/media');

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
        final file = File('example/lib/media/${fixture}_fixture.dart');

        expect(file.existsSync(), isTrue);
      });
    }
  });
}
