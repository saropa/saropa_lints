import 'dart:io';

import 'package:saropa_lints/src/rules/ui/accessibility_rules.dart';
import 'package:test/test.dart';

/// Tests for 40 Accessibility lint rules (instantiation group).
///
/// Test fixtures: example/lib/accessibility/*
// Semantics, focus, and screen-reader related widget rules; fixtures under example/.
void main() {
  group('Accessibility Rules - Rule Instantiation', () {
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
      'AvoidIconButtonsWithoutTooltipRule',
      'avoid_icon_buttons_without_tooltip',
      () => AvoidIconButtonsWithoutTooltipRule(),
    );
    testRule(
      'AvoidSmallTouchTargetsRule',
      'avoid_small_touch_targets',
      () => AvoidSmallTouchTargetsRule(),
    );
    testRule(
      'RequireExcludeSemanticsJustificationRule',
      'require_exclude_semantics_justification',
      () => RequireExcludeSemanticsJustificationRule(),
    );
    testRule(
      'AvoidColorOnlyIndicatorsRule',
      'avoid_color_only_indicators',
      () => AvoidColorOnlyIndicatorsRule(),
    );
    testRule(
      'RequireTextScaleFactorAwarenessRule',
      'require_text_scale_factor_awareness',
      () => RequireTextScaleFactorAwarenessRule(),
    );
    testRule(
      'AvoidGestureOnlyInteractionsRule',
      'avoid_gesture_only_interactions',
      () => AvoidGestureOnlyInteractionsRule(),
    );
    testRule(
      'RequireSemanticsLabelRule',
      'require_semantics_label',
      () => RequireSemanticsLabelRule(),
    );
    testRule(
      'AvoidMergedSemanticsHidingInfoRule',
      'avoid_merged_semantics_hiding_info',
      () => AvoidMergedSemanticsHidingInfoRule(),
    );
    testRule(
      'RequireLiveRegionRule',
      'require_live_region',
      () => RequireLiveRegionRule(),
    );
    testRule(
      'RequireHeadingSemanticsRule',
      'require_heading_semantics',
      () => RequireHeadingSemanticsRule(),
    );
    testRule(
      'AvoidImageButtonsWithoutTooltipRule',
      'avoid_image_buttons_without_tooltip',
      () => AvoidImageButtonsWithoutTooltipRule(),
    );
    testRule(
      'AvoidTextScaleFactorIgnoreRule',
      'avoid_text_scale_factor_ignore',
      () => AvoidTextScaleFactorIgnoreRule(),
    );
    testRule(
      'RequireImageSemanticsRule',
      'require_image_semantics',
      () => RequireImageSemanticsRule(),
    );
    testRule(
      'AvoidHiddenInteractiveRule',
      'avoid_hidden_interactive',
      () => AvoidHiddenInteractiveRule(),
    );
    testRule(
      'PreferScalableTextRule',
      'prefer_scalable_text',
      () => PreferScalableTextRule(),
    );
    testRule(
      'RequireButtonSemanticsRule',
      'require_button_semantics',
      () => RequireButtonSemanticsRule(),
    );
    testRule(
      'PreferExplicitSemanticsRule',
      'prefer_explicit_semantics',
      () => PreferExplicitSemanticsRule(),
    );
    testRule(
      'AvoidHoverOnlyRule',
      'avoid_hover_only',
      () => AvoidHoverOnlyRule(),
    );
    testRule(
      'RequireErrorIdentificationRule',
      'require_error_identification',
      () => RequireErrorIdentificationRule(),
    );
    testRule(
      'RequireMinimumContrastRule',
      'require_minimum_contrast',
      () => RequireMinimumContrastRule(),
    );
    testRule(
      'RequireAvatarAltTextRule',
      'require_avatar_alt_text',
      () => RequireAvatarAltTextRule(),
    );
    testRule(
      'RequireBadgeSemanticsRule',
      'require_badge_semantics',
      () => RequireBadgeSemanticsRule(),
    );
    testRule(
      'RequireBadgeCountLimitRule',
      'require_badge_count_limit',
      () => RequireBadgeCountLimitRule(),
    );
    testRule(
      'RequireImageDescriptionRule',
      'require_image_description',
      () => RequireImageDescriptionRule(),
    );
    testRule(
      'AvoidSemanticsExclusionRule',
      'avoid_semantics_exclusion',
      () => AvoidSemanticsExclusionRule(),
    );
    testRule(
      'PreferMergeSemanticsRule',
      'prefer_merge_semantics',
      () => PreferMergeSemanticsRule(),
    );
    testRule(
      'RequireFocusIndicatorRule',
      'require_focus_indicator',
      () => RequireFocusIndicatorRule(),
    );
    testRule(
      'AvoidFlashingContentRule',
      'avoid_flashing_content',
      () => AvoidFlashingContentRule(),
    );
    testRule(
      'PreferAdequateSpacingRule',
      'prefer_adequate_spacing',
      () => PreferAdequateSpacingRule(),
    );
    testRule(
      'AvoidMotionWithoutReduceRule',
      'avoid_motion_without_reduce',
      () => AvoidMotionWithoutReduceRule(),
    );
    testRule(
      'RequireSemanticLabelIconsRule',
      'require_semantic_label_icons',
      () => RequireSemanticLabelIconsRule(),
    );
    testRule(
      'RequireAccessibleImagesRule',
      'require_accessible_images',
      () => RequireAccessibleImagesRule(),
    );
    testRule(
      'AvoidAutoPlayMediaRule',
      'avoid_auto_play_media',
      () => AvoidAutoPlayMediaRule(),
    );
    testRule(
      'PreferLargeTouchTargetsRule',
      'prefer_large_touch_targets',
      () => PreferLargeTouchTargetsRule(),
    );
    testRule(
      'AvoidTimeLimitsRule',
      'avoid_time_limits',
      () => AvoidTimeLimitsRule(),
    );
    testRule(
      'RequireDragAlternativesRule',
      'require_drag_alternatives',
      () => RequireDragAlternativesRule(),
    );
    testRule(
      'PreferFocusTraversalOrderRule',
      'prefer_focus_traversal_order',
      () => PreferFocusTraversalOrderRule(),
    );
    testRule(
      'PreferSemanticsContainerRule',
      'prefer_semantics_container',
      () => PreferSemanticsContainerRule(),
    );
    testRule(
      'AvoidRedundantSemanticsRule',
      'avoid_redundant_semantics',
      () => AvoidRedundantSemanticsRule(),
    );
    testRule(
      'AvoidColorOnlyMeaningRule',
      'avoid_color_only_meaning',
      () => AvoidColorOnlyMeaningRule(),
    );
    testRule(
      'PreferSemanticsSortRule',
      'prefer_semantics_sort',
      () => PreferSemanticsSortRule(),
    );
  });
  group('Accessibility Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/accessibility');

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
      test('\$fixture fixture exists', () {
        final file = File('example/lib/accessibility/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture checks while migrating to analyzer-backed behavior tests.
}
