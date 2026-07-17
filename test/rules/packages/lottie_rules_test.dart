import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/lottie_rules.dart';
import '../../helpers/fixture_discovery.dart';

/// Instantiation-pin tests for 5 lottie lint rules.
///
/// Each test confirms:
///   - The rule constructs without error.
///   - `code.lowerCaseName` matches the snake_case rule name.
///   - `code.problemMessage` starts with the `[rule_name]` prefix.
///   - `code.problemMessage` is >200 characters (required by convention).
///   - `code.correctionMessage` is non-null.
///
/// Test fixtures: example_packages/lib/lottie/lottie_fixture.dart
void main() {
  group('Lottie Rules - Rule Instantiation', () {
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
      'LottieControllerMissingOnLoadedRule',
      'lottie_controller_missing_on_loaded',
      () => LottieControllerMissingOnLoadedRule(),
    );
    testRule(
      'LottieNetworkMissingErrorBuilderRule',
      'lottie_network_missing_error_builder',
      () => LottieNetworkMissingErrorBuilderRule(),
    );
    testRule(
      'LottieFrameRateMaxWithoutRenderCacheRule',
      'lottie_frame_rate_max_without_render_cache',
      () => LottieFrameRateMaxWithoutRenderCacheRule(),
    );
    testRule(
      'LottieRenderCacheRasterLargeRiskRule',
      'lottie_render_cache_raster_large_risk',
      () => LottieRenderCacheRasterLargeRiskRule(),
    );
    testRule(
      'LottieNetworkMissingBackgroundLoadingRule',
      'lottie_network_missing_background_loading',
      () => LottieNetworkMissingBackgroundLoadingRule(),
    );
  });

  group('Lottie Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/lottie');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/lottie/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });
}
