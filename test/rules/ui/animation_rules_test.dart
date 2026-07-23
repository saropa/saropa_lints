import 'dart:io';

import 'package:saropa_lints/src/rules/ui/animation_rules.dart';
import 'package:test/test.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for 20 Animation lint rules.
///
/// Test fixtures: example/lib/animation/*
void main() {
  group('Animation Rules - Rule Instantiation', () {
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
      'RequireVsyncMixinRule',
      'require_vsync_mixin',
      () => RequireVsyncMixinRule(),
    );
    testRule(
      'AvoidAnimationInBuildRule',
      'avoid_animation_in_build',
      () => AvoidAnimationInBuildRule(),
    );
    testRule(
      'AvoidInertAnimationValueInBuildRule',
      'avoid_inert_animation_value_in_build',
      () => AvoidInertAnimationValueInBuildRule(),
    );
    testRule(
      'RequireAnimationControllerDisposeRule',
      'require_animation_controller_dispose',
      () => RequireAnimationControllerDisposeRule(),
    );
    test('RequireAnimationControllerDisposeRule relatedRules', () {
      final rule = RequireAnimationControllerDisposeRule();
      expect(
        rule.relatedRules,
        containsAll(<String>[
          'require_dispose_implementation',
          'require_stream_controller_dispose',
          'require_animation_ticker_disposal',
        ]),
      );
    });
    testRule(
      'RequireHeroTagUniquenessRule',
      'require_hero_tag_uniqueness',
      () => RequireHeroTagUniquenessRule(),
    );
    testRule(
      'AvoidLayoutPassesRule',
      'avoid_layout_passes',
      () => AvoidLayoutPassesRule(),
    );
    testRule(
      'AvoidHardcodedDurationRule',
      'avoid_hardcoded_duration',
      () => AvoidHardcodedDurationRule(),
    );
    testRule(
      'RequireAnimationCurveRule',
      'require_animation_curve',
      () => RequireAnimationCurveRule(),
    );
    testRule(
      'PreferImplicitAnimationsRule',
      'prefer_implicit_animations',
      () => PreferImplicitAnimationsRule(),
    );
    testRule(
      'RequireStaggeredAnimationDelaysRule',
      'require_staggered_animation_delays',
      () => RequireStaggeredAnimationDelaysRule(),
    );
    testRule(
      'PreferTweenSequenceRule',
      'prefer_tween_sequence',
      () => PreferTweenSequenceRule(),
    );
    testRule(
      'RequireAnimationStatusListenerRule',
      'require_animation_status_listener',
      () => RequireAnimationStatusListenerRule(),
    );
    testRule(
      'AvoidOverlappingAnimationsRule',
      'avoid_overlapping_animations',
      () => AvoidOverlappingAnimationsRule(),
    );
    testRule(
      'AvoidAnimationRebuildWasteRule',
      'avoid_animation_rebuild_waste',
      () => AvoidAnimationRebuildWasteRule(),
    );
    testRule(
      'PreferPhysicsSimulationRule',
      'prefer_physics_simulation',
      () => PreferPhysicsSimulationRule(),
    );
    testRule(
      'RequireAnimationTickerDisposalRule',
      'require_animation_ticker_disposal',
      () => RequireAnimationTickerDisposalRule(),
    );
    testRule(
      'PreferSpringAnimationRule',
      'prefer_spring_animation',
      () => PreferSpringAnimationRule(),
    );
    testRule(
      'AvoidExcessiveRebuildsAnimationRule',
      'avoid_excessive_rebuilds_animation',
      () => AvoidExcessiveRebuildsAnimationRule(),
    );
    testRule(
      'AvoidClipDuringAnimationRule',
      'avoid_clip_during_animation',
      () => AvoidClipDuringAnimationRule(),
    );
    testRule(
      'AvoidMultipleAnimationControllersRule',
      'avoid_multiple_animation_controllers',
      () => AvoidMultipleAnimationControllersRule(),
    );
    testRule(
      'AvoidImplicitAnimationDisposeCastRule',
      'avoid_implicit_animation_dispose_cast',
      () => AvoidImplicitAnimationDisposeCastRule(),
    );
    testRule(
      'PreferAnimationControllerForwardFromZeroRule',
      'prefer_animation_controller_forward_from_zero',
      () => PreferAnimationControllerForwardFromZeroRule(),
    );
    testRule(
      'PreferSingleTickerProviderStateMixinRule',
      'prefer_single_ticker_provider_state_mixin',
      () => PreferSingleTickerProviderStateMixinRule(),
    );
  });

  group('Animation Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/animation');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/animation/${fixture}_fixture.dart');

        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture verification while migrating to analyzer-backed behavior tests.
}
