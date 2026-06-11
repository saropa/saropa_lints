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
    final fixtures = [
      'youtube_player_controller_not_closed',
      'youtube_player_convert_url_unchecked',
      'youtube_player_scaffold_deprecated',
      'youtube_player_mute_not_respected_in_params',
      'youtube_player_auto_fullscreen_without_portrait_guard',
    ];

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
