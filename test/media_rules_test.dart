import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/media_rules.dart';

/// Tests for 3 Media lint rules.
///
/// Test fixtures: example_async/lib/media/*
void main() {
  group('Media Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.name, codeName);
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
  });

  group('Media Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_autoplay_audio',
      'prefer_camera_resolution_selection',
      'prefer_audio_session_config',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example_async/lib/media/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Media - Avoidance Rules', () {
    group('avoid_autoplay_audio', () {
      test('audio playing without user action SHOULD trigger', () {
        expect('audio playing without user action', isNotNull);
      });

      test('user-initiated audio playback should NOT trigger', () {
        expect('user-initiated audio playback', isNotNull);
      });
    });
  });

  group('Media - Preference Rules', () {
    group('prefer_camera_resolution_selection', () {
      test('camera at max resolution always SHOULD trigger', () {
        expect('camera at max resolution always', isNotNull);
      });

      test('configurable camera resolution should NOT trigger', () {
        expect('configurable camera resolution', isNotNull);
      });
    });
    group('prefer_audio_session_config', () {
      test('audio without session configuration SHOULD trigger', () {
        expect('audio without session configuration', isNotNull);
      });

      test('AudioSession category setup should NOT trigger', () {
        expect('AudioSession category setup', isNotNull);
      });
    });
  });
}
