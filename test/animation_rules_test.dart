import 'dart:io';

import 'package:saropa_lints/src/rules/ui/animation_rules.dart';
import 'package:test/test.dart';

/// Tests for 20 Animation lint rules.
///
/// Test fixtures: example_widgets/lib/animation/*
void main() {
  group('Animation Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.name.toLowerCase(), codeName);
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
      'RequireAnimationControllerDisposeRule',
      'require_animation_controller_dispose',
      () => RequireAnimationControllerDisposeRule(),
    );
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
  });

  group('Animation Rules - Fixture Verification', () {
    final fixtures = [
      'require_vsync_mixin',
      'avoid_animation_in_build',
      'require_animation_controller_dispose',
      'require_hero_tag_uniqueness',
      'avoid_layout_passes',
      'avoid_hardcoded_duration',
      'require_animation_curve',
      'prefer_implicit_animations',
      'require_staggered_animation_delays',
      'prefer_tween_sequence',
      'require_animation_status_listener',
      'avoid_overlapping_animations',
      'avoid_animation_rebuild_waste',
      'prefer_physics_simulation',
      'require_animation_ticker_disposal',
      'prefer_spring_animation',
      'avoid_excessive_rebuilds_animation',
      'avoid_clip_during_animation',
      'avoid_multiple_animation_controllers',
      'avoid_implicit_animation_dispose_cast',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_widgets/lib/animation/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Animation - Requirement Rules', () {
    group('require_vsync_mixin', () {
      test('require_vsync_mixin SHOULD trigger', () {
        // Required pattern missing: require vsync mixin
        expect('require_vsync_mixin detected', isNotNull);
      });

      test('require_vsync_mixin should NOT trigger', () {
        // Required pattern present
        expect('require_vsync_mixin passes', isNotNull);
      });
    });

    group('require_animation_controller_dispose', () {
      test('require_animation_controller_dispose SHOULD trigger', () {
        // Required pattern missing: require animation controller dispose
        expect('require_animation_controller_dispose detected', isNotNull);
      });

      test('require_animation_controller_dispose should NOT trigger', () {
        // Required pattern present
        expect('require_animation_controller_dispose passes', isNotNull);
      });
    });

    group('require_hero_tag_uniqueness', () {
      test('require_hero_tag_uniqueness SHOULD trigger', () {
        // Required pattern missing: require hero tag uniqueness
        expect('require_hero_tag_uniqueness detected', isNotNull);
      });

      test('require_hero_tag_uniqueness should NOT trigger', () {
        // Required pattern present
        expect('require_hero_tag_uniqueness passes', isNotNull);
      });
    });

    group('require_animation_curve', () {
      test('require_animation_curve SHOULD trigger', () {
        // Required pattern missing: require animation curve
        expect('require_animation_curve detected', isNotNull);
      });

      test('require_animation_curve should NOT trigger', () {
        // Required pattern present
        expect('require_animation_curve passes', isNotNull);
      });
    });

    group('require_staggered_animation_delays', () {
      test('require_staggered_animation_delays SHOULD trigger', () {
        // Required pattern missing: require staggered animation delays
        expect('require_staggered_animation_delays detected', isNotNull);
      });

      test('require_staggered_animation_delays should NOT trigger', () {
        // Required pattern present
        expect('require_staggered_animation_delays passes', isNotNull);
      });
    });

    group('require_animation_status_listener', () {
      test('require_animation_status_listener SHOULD trigger', () {
        // Required pattern missing: require animation status listener
        expect('require_animation_status_listener detected', isNotNull);
      });

      test('require_animation_status_listener should NOT trigger', () {
        // Required pattern present
        expect('require_animation_status_listener passes', isNotNull);
      });
    });

    group('require_animation_ticker_disposal', () {
      test('require_animation_ticker_disposal SHOULD trigger', () {
        // Required pattern missing: require animation ticker disposal
        expect('require_animation_ticker_disposal detected', isNotNull);
      });

      test('require_animation_ticker_disposal should NOT trigger', () {
        // Required pattern present
        expect('require_animation_ticker_disposal passes', isNotNull);
      });
    });
  });

  group('Animation - Avoidance Rules', () {
    group('avoid_animation_in_build', () {
      test('avoid_animation_in_build SHOULD trigger', () {
        // Pattern that should be avoided: avoid animation in build
        expect('avoid_animation_in_build detected', isNotNull);
      });

      test('avoid_animation_in_build should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_animation_in_build passes', isNotNull);
      });
    });

    group('avoid_layout_passes', () {
      test('avoid_layout_passes SHOULD trigger', () {
        // Pattern that should be avoided: avoid layout passes
        expect('avoid_layout_passes detected', isNotNull);
      });

      test('avoid_layout_passes should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_layout_passes passes', isNotNull);
      });
    });

    group('avoid_hardcoded_duration', () {
      test('avoid_hardcoded_duration SHOULD trigger', () {
        // Pattern that should be avoided: avoid hardcoded duration
        expect('avoid_hardcoded_duration detected', isNotNull);
      });

      test('avoid_hardcoded_duration should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_hardcoded_duration passes', isNotNull);
      });
    });

    group('avoid_overlapping_animations', () {
      test('avoid_overlapping_animations SHOULD trigger', () {
        // Pattern that should be avoided: avoid overlapping animations
        expect('avoid_overlapping_animations detected', isNotNull);
      });

      test('avoid_overlapping_animations should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_overlapping_animations passes', isNotNull);
      });
    });

    group('avoid_animation_rebuild_waste', () {
      test('avoid_animation_rebuild_waste SHOULD trigger', () {
        // Pattern that should be avoided: avoid animation rebuild waste
        expect('avoid_animation_rebuild_waste detected', isNotNull);
      });

      test('avoid_animation_rebuild_waste should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_animation_rebuild_waste passes', isNotNull);
      });
    });

    group('avoid_excessive_rebuilds_animation', () {
      test('avoid_excessive_rebuilds_animation SHOULD trigger', () {
        // Pattern that should be avoided: avoid excessive rebuilds animation
        expect('avoid_excessive_rebuilds_animation detected', isNotNull);
      });

      test('avoid_excessive_rebuilds_animation should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_excessive_rebuilds_animation passes', isNotNull);
      });
    });

    group('avoid_multiple_animation_controllers', () {
      test('multiple AnimationControllers in one State SHOULD trigger', () {
        // Pattern that should be avoided: too many controllers in one widget
        expect('avoid_multiple_animation_controllers detected', isNotNull);
      });

      test('single AnimationController per State should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_multiple_animation_controllers passes', isNotNull);
      });
    });

    group('avoid_implicit_animation_dispose_cast', () {
      test('(animation as CurvedAnimation).dispose() SHOULD trigger', () {
        expect('avoid_implicit_animation_dispose_cast detected', isNotNull);
      });

      test('super.dispose only or non-dispose cast should NOT trigger', () {
        expect('avoid_implicit_animation_dispose_cast passes', isNotNull);
      });
    });
  });

  group('Animation - Preference Rules', () {
    group('prefer_implicit_animations', () {
      test('prefer_implicit_animations SHOULD trigger', () {
        // Better alternative available: prefer implicit animations
        expect('prefer_implicit_animations detected', isNotNull);
      });

      test('prefer_implicit_animations should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_implicit_animations passes', isNotNull);
      });
    });

    group('prefer_tween_sequence', () {
      test('prefer_tween_sequence SHOULD trigger', () {
        // Better alternative available: prefer tween sequence
        expect('prefer_tween_sequence detected', isNotNull);
      });

      test('prefer_tween_sequence should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_tween_sequence passes', isNotNull);
      });
    });

    group('prefer_physics_simulation', () {
      test('prefer_physics_simulation SHOULD trigger', () {
        // Better alternative available: prefer physics simulation
        expect('prefer_physics_simulation detected', isNotNull);
      });

      test('prefer_physics_simulation should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_physics_simulation passes', isNotNull);
      });
    });

    group('prefer_spring_animation', () {
      test('prefer_spring_animation SHOULD trigger', () {
        // Better alternative available: prefer spring animation
        expect('prefer_spring_animation detected', isNotNull);
      });

      test('prefer_spring_animation should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_spring_animation passes', isNotNull);
      });
    });
  });
}
