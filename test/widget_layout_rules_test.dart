import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/widget/widget_layout_constraints_rules.dart';
import 'package:saropa_lints/src/rules/widget/widget_layout_flex_scroll_rules.dart';

/// Tests for 73 widget layout lint rules.
///
/// These rules cover layout constraints, scroll behavior, Container
/// alternatives, nesting depth, responsive design, and layout performance.
///
/// Test fixtures: example/lib/widget_layout/*
void main() {
  group('Widget Layout Rules - Rule Instantiation', () {
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
      'AvoidExpandedAsSpacerRule',
      'avoid_expanded_as_spacer',
      () => AvoidExpandedAsSpacerRule(),
    );

    testRule(
      'AvoidFlexibleOutsideFlexRule',
      'avoid_flexible_outside_flex',
      () => AvoidFlexibleOutsideFlexRule(),
    );

    testRule(
      'AvoidMisnamedPaddingRule',
      'avoid_misnamed_padding',
      () => AvoidMisnamedPaddingRule(),
    );

    testRule(
      'AvoidShrinkWrapInListsRule',
      'avoid_shrink_wrap_in_lists',
      () => AvoidShrinkWrapInListsRule(),
    );

    testRule(
      'AvoidSingleChildColumnRowRule',
      'avoid_single_child_column_row',
      () => AvoidSingleChildColumnRowRule(),
    );

    testRule(
      'AvoidWrappingInPaddingRule',
      'avoid_wrapping_in_padding',
      () => AvoidWrappingInPaddingRule(),
    );

    testRule(
      'CheckForEqualsInRenderObjectSettersRule',
      'check_for_equals_in_render_object_setters',
      () => CheckForEqualsInRenderObjectSettersRule(),
    );

    testRule(
      'ConsistentUpdateRenderObjectRule',
      'consistent_update_render_object',
      () => ConsistentUpdateRenderObjectRule(),
    );

    testRule(
      'PreferConstBorderRadiusRule',
      'prefer_const_border_radius',
      () => PreferConstBorderRadiusRule(),
    );

    testRule(
      'PreferCorrectEdgeInsetsConstructorRule',
      'prefer_correct_edge_insets_constructor',
      () => PreferCorrectEdgeInsetsConstructorRule(),
    );

    testRule(
      'PreferSliverPrefixRule',
      'prefer_sliver_prefix',
      () => PreferSliverPrefixRule(),
    );

    testRule(
      'PreferUsingListViewRule',
      'prefer_using_list_view',
      () => PreferUsingListViewRule(),
    );

    testRule(
      'AvoidBorderAllRule',
      'avoid_border_all',
      () => AvoidBorderAllRule(),
    );

    testRule(
      'AvoidDeeplyNestedWidgetsRule',
      'avoid_deeply_nested_widgets',
      () => AvoidDeeplyNestedWidgetsRule(),
    );

    testRule(
      'PreferConstWidgetsInListsRule',
      'prefer_const_widgets_in_lists',
      () => PreferConstWidgetsInListsRule(),
    );

    testRule(
      'AvoidListViewWithoutItemExtentRule',
      'avoid_listview_without_item_extent',
      () => AvoidListViewWithoutItemExtentRule(),
    );

    testRule(
      'PreferSliverListDelegateRule',
      'prefer_sliver_list_delegate',
      () => PreferSliverListDelegateRule(),
    );

    testRule(
      'AvoidLayoutBuilderMisuseRule',
      'avoid_layout_builder_misuse',
      () => AvoidLayoutBuilderMisuseRule(),
    );

    testRule(
      'AvoidRepaintBoundaryMisuseRule',
      'avoid_repaint_boundary_misuse',
      () => AvoidRepaintBoundaryMisuseRule(),
    );

    testRule(
      'AvoidSingleChildScrollViewWithColumnRule',
      'avoid_singlechildscrollview_with_column',
      () => AvoidSingleChildScrollViewWithColumnRule(),
    );

    testRule(
      'AvoidGestureDetectorInScrollViewRule',
      'avoid_gesture_detector_in_scrollview',
      () => AvoidGestureDetectorInScrollViewRule(),
    );

    testRule(
      'PreferOpacityWidgetRule',
      'prefer_opacity_widget',
      () => PreferOpacityWidgetRule(),
    );

    testRule(
      'PreferSizedBoxForWhitespaceRule',
      'prefer_sized_box_for_whitespace',
      () => PreferSizedBoxForWhitespaceRule(),
    );

    testRule(
      'AvoidNestedScaffoldsRule',
      'avoid_nested_scaffolds',
      () => AvoidNestedScaffoldsRule(),
    );

    testRule(
      'PreferListViewBuilderRule',
      'prefer_listview_builder',
      () => PreferListViewBuilderRule(),
    );

    testRule(
      'AvoidSizedBoxExpandRule',
      'avoid_sized_box_expand',
      () => AvoidSizedBoxExpandRule(),
    );

    testRule(
      'PreferSpacingOverSizedBoxRule',
      'prefer_spacing_over_sizedbox',
      () => PreferSpacingOverSizedBoxRule(),
    );

    testRule(
      'AvoidNestedScrollablesRule',
      'avoid_nested_scrollables',
      () => AvoidNestedScrollablesRule(),
    );

    testRule(
      'AvoidHardcodedLayoutValuesRule',
      'avoid_hardcoded_layout_values',
      () => AvoidHardcodedLayoutValuesRule(),
    );

    testRule(
      'PreferIgnorePointerRule',
      'prefer_ignore_pointer',
      () => PreferIgnorePointerRule(),
    );

    testRule(
      'PreferPageStorageKeyRule',
      'prefer_page_storage_key',
      () => PreferPageStorageKeyRule(),
    );

    testRule(
      'RequireScrollPhysicsRule',
      'require_scroll_physics',
      () => RequireScrollPhysicsRule(),
    );

    testRule(
      'PreferSliverListRule',
      'prefer_sliver_list',
      () => PreferSliverListRule(),
    );

    testRule(
      'PreferKeepAliveRule',
      'prefer_keep_alive',
      () => PreferKeepAliveRule(),
    );

    testRule(
      'PreferWrapOverOverflowRule',
      'prefer_wrap_over_overflow',
      () => PreferWrapOverOverflowRule(),
    );

    testRule(
      'AvoidLayoutBuilderInScrollableRule',
      'avoid_layout_builder_in_scrollable',
      () => AvoidLayoutBuilderInScrollableRule(),
    );

    testRule(
      'PreferIntrinsicDimensionsRule',
      'prefer_intrinsic_dimensions',
      () => PreferIntrinsicDimensionsRule(),
    );

    testRule(
      'AvoidUnboundedConstraintsRule',
      'avoid_unbounded_constraints',
      () => AvoidUnboundedConstraintsRule(),
    );

    testRule(
      'PreferFractionalSizingRule',
      'prefer_fractional_sizing',
      () => PreferFractionalSizingRule(),
    );

    testRule(
      'PreferLayoutBuilderForConstraintsRule',
      'prefer_layout_builder_for_constraints',
      () => PreferLayoutBuilderForConstraintsRule(),
    );

    testRule(
      'AvoidUnconstrainedBoxMisuseRule',
      'avoid_unconstrained_box_misuse',
      () => AvoidUnconstrainedBoxMisuseRule(),
    );

    testRule(
      'PreferSliverAppBarRule',
      'prefer_sliver_app_bar',
      () => PreferSliverAppBarRule(),
    );

    testRule(
      'AvoidOpacityMisuseRule',
      'avoid_opacity_misuse',
      () => AvoidOpacityMisuseRule(),
    );

    testRule(
      'PreferClipBehaviorRule',
      'prefer_clip_behavior',
      () => PreferClipBehaviorRule(),
    );

    testRule(
      'RequireScrollControllerRule',
      'require_scroll_controller',
      () => RequireScrollControllerRule(),
    );

    testRule(
      'PreferPositionedDirectionalRule',
      'prefer_positioned_directional',
      () => PreferPositionedDirectionalRule(),
    );

    testRule(
      'AvoidShrinkWrapInScrollRule',
      'avoid_shrink_wrap_in_scroll',
      () => AvoidShrinkWrapInScrollRule(),
    );

    testRule(
      'AvoidDeepWidgetNestingRule',
      'avoid_deep_widget_nesting',
      () => AvoidDeepWidgetNestingRule(),
    );

    testRule(
      'PreferSafeAreaAwareRule',
      'prefer_safe_area_aware',
      () => PreferSafeAreaAwareRule(),
    );

    testRule(
      'AvoidFixedDimensionsRule',
      'avoid_fixed_dimensions',
      () => AvoidFixedDimensionsRule(),
    );

    testRule(
      'AvoidAbsorbPointerMisuseRule',
      'avoid_absorb_pointer_misuse',
      () => AvoidAbsorbPointerMisuseRule(),
    );

    testRule(
      'RequireOverflowBoxRationaleRule',
      'require_overflow_box_rationale',
      () => RequireOverflowBoxRationaleRule(),
    );

    testRule(
      'AvoidUnconstrainedImagesRule',
      'avoid_unconstrained_images',
      () => AvoidUnconstrainedImagesRule(),
    );

    testRule(
      'PreferSizedBoxSquareRule',
      'prefer_sized_box_square',
      () => PreferSizedBoxSquareRule(),
    );

    testRule(
      'PreferCenterOverAlignRule',
      'prefer_center_over_align',
      () => PreferCenterOverAlignRule(),
    );

    testRule(
      'PreferAlignOverContainerRule',
      'prefer_align_over_container',
      () => PreferAlignOverContainerRule(),
    );

    testRule(
      'PreferPaddingOverContainerRule',
      'prefer_padding_over_container',
      () => PreferPaddingOverContainerRule(),
    );

    testRule(
      'PreferConstrainedBoxOverContainerRule',
      'prefer_constrained_box_over_container',
      () => PreferConstrainedBoxOverContainerRule(),
    );

    testRule(
      'PreferTransformOverContainerRule',
      'prefer_transform_over_container',
      () => PreferTransformOverContainerRule(),
    );

    testRule(
      'RequirePhysicsForNestedScrollRule',
      'require_physics_for_nested_scroll',
      () => RequirePhysicsForNestedScrollRule(),
    );

    testRule(
      'AvoidStackWithoutPositionedRule',
      'avoid_stack_without_positioned',
      () => AvoidStackWithoutPositionedRule(),
    );

    testRule(
      'AvoidExpandedOutsideFlexRule',
      'avoid_expanded_outside_flex',
      () => AvoidExpandedOutsideFlexRule(),
    );

    testRule(
      'PreferExpandedAtCallSiteRule',
      'prefer_expanded_at_call_site',
      () => PreferExpandedAtCallSiteRule(),
    );

    testRule(
      'AvoidBuilderIndexOutOfBoundsRule',
      'avoid_builder_index_out_of_bounds',
      () => AvoidBuilderIndexOutOfBoundsRule(),
    );

    testRule(
      'PreferCustomSingleChildLayoutRule',
      'prefer_custom_single_child_layout',
      () => PreferCustomSingleChildLayoutRule(),
    );

    testRule(
      'AvoidTableCellOutsideTableRule',
      'avoid_table_cell_outside_table',
      () => AvoidTableCellOutsideTableRule(),
    );

    testRule(
      'AvoidPositionedOutsideStackRule',
      'avoid_positioned_outside_stack',
      () => AvoidPositionedOutsideStackRule(),
    );

    testRule(
      'AvoidSpacerInWrapRule',
      'avoid_spacer_in_wrap',
      () => AvoidSpacerInWrapRule(),
    );

    testRule(
      'AvoidScrollableInIntrinsicRule',
      'avoid_scrollable_in_intrinsic',
      () => AvoidScrollableInIntrinsicRule(),
    );

    testRule(
      'RequireBaselineTextBaselineRule',
      'require_baseline_text_baseline',
      () => RequireBaselineTextBaselineRule(),
    );

    testRule(
      'AvoidUnconstrainedDialogColumnRule',
      'avoid_unconstrained_dialog_column',
      () => AvoidUnconstrainedDialogColumnRule(),
    );

    testRule(
      'AvoidUnboundedListviewInColumnRule',
      'avoid_unbounded_listview_in_column',
      () => AvoidUnboundedListviewInColumnRule(),
    );

    testRule(
      'AvoidTextfieldInRowRule',
      'avoid_textfield_in_row',
      () => AvoidTextfieldInRowRule(),
    );

    testRule(
      'AvoidFixedSizeInScaffoldBodyRule',
      'avoid_fixed_size_in_scaffold_body',
      () => AvoidFixedSizeInScaffoldBodyRule(),
    );

    testRule(
      'PreferFlexForComplexLayoutRule',
      'prefer_flex_for_complex_layout',
      () => PreferFlexForComplexLayoutRule(),
    );
    testRule(
      'PreferFindChildIndexCallbackRule',
      'prefer_find_child_index_callback',
      () => PreferFindChildIndexCallbackRule(),
    );
  });

  group('Widget Layout Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_absorb_pointer_misuse',
      'avoid_border_all',
      'avoid_deep_widget_nesting',
      'avoid_deeply_nested_widgets',
      'avoid_expanded_as_spacer',
      'avoid_fixed_dimensions',
      'avoid_flexible_outside_flex',
      'avoid_gesture_detector_in_scrollview',
      'avoid_hardcoded_layout_values',
      'avoid_layout_builder_in_scrollable',
      'avoid_layout_builder_misuse',
      'avoid_listview_without_item_extent',
      'avoid_misnamed_padding',
      'avoid_nested_scaffolds',
      'avoid_nested_scrollables',
      'avoid_opacity_misuse',
      'avoid_repaint_boundary_misuse',
      'avoid_shrink_wrap_in_lists',
      'avoid_shrink_wrap_in_scroll',
      'avoid_singlechildscrollview_with_column',
      'avoid_sized_box_expand',
      'avoid_unconstrained_box_misuse',
      'avoid_unconstrained_images',
      'avoid_wrapping_in_padding',
      'check_for_equals_in_render_object_setters',
      'consistent_update_render_object',
      'prefer_clip_behavior',
      'prefer_const_border_radius',
      'prefer_const_widgets_in_lists',
      'prefer_correct_edge_insets_constructor',
      'prefer_custom_single_child_layout',
      'prefer_find_child_index_callback',
      'prefer_flex_for_complex_layout',
      'prefer_fractional_sizing',
      'prefer_layout_builder_for_constraints',
      'prefer_ignore_pointer',
      'prefer_intrinsic_dimensions',
      'prefer_keep_alive',
      'prefer_listview_builder',
      'prefer_opacity_widget',
      'prefer_page_storage_key',
      'prefer_positioned_directional',
      'prefer_safe_area_aware',
      'prefer_sized_box_for_whitespace',
      'prefer_sliver_app_bar',
      'prefer_sliver_list',
      'prefer_sliver_list_delegate',
      'prefer_sliver_prefix',
      'prefer_spacing_over_sizedbox',
      'prefer_transform_over_container',
      'prefer_using_list_view',
      'prefer_wrap_over_overflow',
      'require_overflow_box_rationale',
      'require_physics_for_nested_scroll',
      'require_scroll_controller',
      'require_scroll_physics',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/widget_layout/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture checks while migrating to analyzer-backed behavior tests.
}
