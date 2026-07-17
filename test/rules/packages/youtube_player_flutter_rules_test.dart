import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/youtube_player_flutter_rules.dart';

/// Tests for 5 youtube_player_flutter lint rules.
///
/// Test fixtures: example_packages/lib/youtube_player_flutter/*
void main() {
  group('YoutubePlayerFlutter Rules - Rule Instantiation', () {
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
      'YoutubePlayerControllerNotClosedRule',
      'youtube_player_controller_not_closed',
      () => YoutubePlayerControllerNotClosedRule(),
    );
    testRule(
      'YoutubePlayerConvertUrlUncheckedRule',
      'youtube_player_convert_url_unchecked',
      () => YoutubePlayerConvertUrlUncheckedRule(),
    );
    testRule(
      'YoutubePlayerScaffoldDeprecatedRule',
      'youtube_player_scaffold_deprecated',
      () => YoutubePlayerScaffoldDeprecatedRule(),
    );
    testRule(
      'YoutubePlayerMuteNotRespectedInParamsRule',
      'youtube_player_mute_not_respected_in_params',
      () => YoutubePlayerMuteNotRespectedInParamsRule(),
    );
    testRule(
      'YoutubePlayerAutoFullscreenWithoutPortraitGuardRule',
      'youtube_player_auto_fullscreen_without_portrait_guard',
      () => YoutubePlayerAutoFullscreenWithoutPortraitGuardRule(),
    );
  });

  group('YoutubePlayerFlutter Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/youtube_player_flutter');

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
          'example_packages/lib/youtube_player_flutter/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });
}
