import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/audioplayers_rules.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for 6 audioplayers lint rules.
///
/// These complement the repo's existing media coverage (require_media_player_dispose
/// already lists AudioPlayer/AudioCache; require_stream_subscription_cancel covers
/// generic subscription leaks). They target the gaps: AudioPool lifecycle, the
/// PlayerMode.lowLatency event/seek dead-code traps, the ReleaseMode.loop +
/// onPlayerComplete dead-listener trap, UrlSource-for-asset paths, and out-of-range
/// volume literals.
///
/// Test fixtures: example_packages/lib/audioplayers/*
void main() {
  group('Audioplayers Rules - Rule Instantiation', () {
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
      'AudioplayersPoolNotDisposedRule',
      'audioplayers_pool_not_disposed',
      () => AudioplayersPoolNotDisposedRule(),
    );
    testRule(
      'AudioplayersLowLatencyWithStreamListenRule',
      'audioplayers_low_latency_with_stream_listen',
      () => AudioplayersLowLatencyWithStreamListenRule(),
    );
    testRule(
      'AudioplayersLowLatencyWithSeekRule',
      'audioplayers_low_latency_with_seek',
      () => AudioplayersLowLatencyWithSeekRule(),
    );
    testRule(
      'AudioplayersReleaseModeLoopWithCompleteListenerRule',
      'audioplayers_release_mode_loop_with_complete_listener',
      () => AudioplayersReleaseModeLoopWithCompleteListenerRule(),
    );
    testRule(
      'AudioplayersUrlSourceInAssetContextRule',
      'audioplayers_url_source_in_asset_context',
      () => AudioplayersUrlSourceInAssetContextRule(),
    );
    testRule(
      'AudioplayersHardcodedVolumeAboveOneRule',
      'audioplayers_hardcoded_volume_above_one',
      () => AudioplayersHardcodedVolumeAboveOneRule(),
    );
  });

  group('Audioplayers Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/audioplayers');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/audioplayers/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });
}
