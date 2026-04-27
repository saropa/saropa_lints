import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/widget/widget_patterns_avoid_prefer_rules.dart';
import 'package:saropa_lints/src/rules/widget/widget_patterns_require_rules.dart';
import 'package:saropa_lints/src/rules/widget/widget_patterns_ux_rules.dart';

/// Tests for 104 widget pattern lint rules.
///
/// These rules cover widget structure, accessibility, theming, navigation,
/// form handling, image patterns, gesture handling, and platform integration.
///
/// Test fixtures: example/lib/widget_patterns/*
void main() {
  group('Widget Patterns Rules - Rule Instantiation', () {
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
      'AvoidIncorrectImageOpacityRule',
      'avoid_incorrect_image_opacity',
      () => AvoidIncorrectImageOpacityRule(),
    );

    testRule(
      'AvoidMissingImageAltRule',
      'avoid_missing_image_alt',
      () => AvoidMissingImageAltRule(),
    );

    testRule(
      'AvoidReturningWidgetsRule',
      'avoid_returning_widgets',
      () => AvoidReturningWidgetsRule(),
    );

    testRule(
      'AvoidUnnecessaryGestureDetectorRule',
      'avoid_unnecessary_gesture_detector',
      () => AvoidUnnecessaryGestureDetectorRule(),
    );

    testRule(
      'PreferDefineHeroTagRule',
      'prefer_define_hero_tag',
      () => PreferDefineHeroTagRule(),
    );

    testRule(
      'PreferExtractingCallbacksRule',
      'prefer_extracting_callbacks',
      () => PreferExtractingCallbacksRule(),
    );

    testRule(
      'PreferSingleWidgetPerFileRule',
      'prefer_single_widget_per_file',
      () => PreferSingleWidgetPerFileRule(),
    );

    testRule(
      'PreferTextRichRule',
      'prefer_text_rich',
      () => PreferTextRichRule(),
    );

    testRule(
      'PreferWidgetPrivateMembersRule',
      'prefer_widget_private_members',
      () => PreferWidgetPrivateMembersRule(),
    );

    testRule(
      'AvoidUncontrolledTextFieldRule',
      'avoid_uncontrolled_text_field',
      () => AvoidUncontrolledTextFieldRule(),
    );

    testRule(
      'AvoidHardcodedAssetPathsRule',
      'avoid_hardcoded_asset_paths',
      () => AvoidHardcodedAssetPathsRule(),
    );

    testRule(
      'AvoidPrintInProductionRule',
      'avoid_print_in_production',
      () => AvoidPrintInProductionRule(),
    );

    testRule(
      'AvoidCatchingGenericExceptionRule',
      'avoid_catching_generic_exception',
      () => AvoidCatchingGenericExceptionRule(),
    );

    testRule(
      'AvoidServiceLocatorOveruseRule',
      'avoid_service_locator_overuse',
      () => AvoidServiceLocatorOveruseRule(),
    );

    testRule(
      'PreferUtcDateTimesRule',
      'prefer_utc_datetimes',
      () => PreferUtcDateTimesRule(),
    );

    testRule(
      'AvoidRegexInLoopRule',
      'avoid_regex_in_loop',
      () => AvoidRegexInLoopRule(),
    );

    testRule(
      'PreferGetterOverMethodRule',
      'prefer_getter_over_method',
      () => PreferGetterOverMethodRule(),
    );

    testRule(
      'AvoidUnusedCallbackParametersRule',
      'avoid_unused_callback_parameters',
      () => AvoidUnusedCallbackParametersRule(),
    );

    testRule(
      'PreferSemanticWidgetNamesRule',
      'prefer_semantic_widget_names',
      () => PreferSemanticWidgetNamesRule(),
    );

    testRule(
      'AvoidTextScaleFactorRule',
      'avoid_text_scale_factor',
      () => AvoidTextScaleFactorRule(),
    );

    testRule(
      'AvoidImageWithoutCacheRule',
      'avoid_image_without_cache',
      () => AvoidImageWithoutCacheRule(),
    );

    testRule(
      'PreferSplitWidgetConstRule',
      'prefer_split_widget_const',
      () => PreferSplitWidgetConstRule(),
    );

    testRule(
      'AvoidNavigatorPushWithoutRouteNameRule',
      'avoid_navigator_push_without_route_name',
      () => AvoidNavigatorPushWithoutRouteNameRule(),
    );

    testRule(
      'AvoidDuplicateWidgetKeysRule',
      'avoid_duplicate_widget_keys',
      () => AvoidDuplicateWidgetKeysRule(),
    );

    testRule(
      'PreferSafeAreaConsumerRule',
      'prefer_safe_area_consumer',
      () => PreferSafeAreaConsumerRule(),
    );

    testRule(
      'AvoidUnrestrictedTextFieldLengthRule',
      'avoid_unrestricted_text_field_length',
      () => AvoidUnrestrictedTextFieldLengthRule(),
    );

    testRule(
      'PreferScaffoldMessengerMaybeOfRule',
      'prefer_scaffold_messenger_maybeof',
      () => PreferScaffoldMessengerMaybeOfRule(),
    );

    testRule(
      'AvoidFormWithoutKeyRule',
      'avoid_form_without_key',
      () => AvoidFormWithoutKeyRule(),
    );

    testRule(
      'AvoidMediaQueryInBuildRule',
      'avoid_mediaquery_in_build',
      () => AvoidMediaQueryInBuildRule(),
    );

    testRule(
      'PreferCachedNetworkImageRule',
      'prefer_cached_network_image',
      () => PreferCachedNetworkImageRule(),
    );

    testRule(
      'AvoidStatefulWidgetInListRule',
      'avoid_stateful_widget_in_list',
      () => AvoidStatefulWidgetInListRule(),
    );

    testRule(
      'AvoidEmptyTextWidgetsRule',
      'avoid_empty_text_widgets',
      () => AvoidEmptyTextWidgetsRule(),
    );

    testRule(
      'AvoidFontWeightAsNumberRule',
      'avoid_font_weight_as_number',
      () => AvoidFontWeightAsNumberRule(),
    );

    testRule(
      'AvoidMultipleMaterialAppsRule',
      'avoid_multiple_material_apps',
      () => AvoidMultipleMaterialAppsRule(),
    );

    testRule(
      'AvoidRawKeyboardListenerRule',
      'avoid_raw_keyboard_listener',
      () => AvoidRawKeyboardListenerRule(),
    );

    testRule(
      'AvoidImageRepeatRule',
      'avoid_image_repeat',
      () => AvoidImageRepeatRule(),
    );

    testRule(
      'AvoidIconSizeOverrideRule',
      'avoid_icon_size_override',
      () => AvoidIconSizeOverrideRule(),
    );

    testRule(
      'PreferInkwellOverGestureRule',
      'prefer_inkwell_over_gesture',
      () => PreferInkwellOverGestureRule(),
    );

    testRule(
      'AvoidFittedBoxForTextRule',
      'avoid_fitted_box_for_text',
      () => AvoidFittedBoxForTextRule(),
    );

    testRule(
      'AvoidOpacityAnimationRule',
      'avoid_opacity_animation',
      () => AvoidOpacityAnimationRule(),
    );

    testRule(
      'PreferSelectableTextRule',
      'prefer_selectable_text',
      () => PreferSelectableTextRule(),
    );

    testRule(
      'AvoidMaterial2FallbackRule',
      'avoid_material2_fallback',
      () => AvoidMaterial2FallbackRule(),
    );

    testRule(
      'PreferOverlayPortalRule',
      'prefer_overlay_portal',
      () => PreferOverlayPortalRule(),
    );

    testRule(
      'PreferCarouselViewRule',
      'prefer_carousel_view',
      () => PreferCarouselViewRule(),
    );

    testRule(
      'PreferSearchAnchorRule',
      'prefer_search_anchor',
      () => PreferSearchAnchorRule(),
    );

    testRule(
      'PreferTapRegionForDismissRule',
      'prefer_tap_region_for_dismiss',
      () => PreferTapRegionForDismissRule(),
    );

    testRule(
      'RequireTextOverflowHandlingRule',
      'require_text_overflow_handling',
      () => RequireTextOverflowHandlingRule(),
    );

    testRule(
      'RequireImageErrorBuilderRule',
      'require_image_error_builder',
      () => RequireImageErrorBuilderRule(),
    );

    testRule(
      'RequireImageDimensionsRule',
      'require_image_dimensions',
      () => RequireImageDimensionsRule(),
    );

    testRule(
      'RequirePlaceholderForNetworkRule',
      'require_placeholder_for_network',
      () => RequirePlaceholderForNetworkRule(),
    );

    testRule(
      'PreferTextThemeRule',
      'prefer_text_theme',
      () => PreferTextThemeRule(),
    );

    testRule(
      'AvoidGestureWithoutBehaviorRule',
      'avoid_gesture_without_behavior',
      () => AvoidGestureWithoutBehaviorRule(),
    );

    testRule(
      'AvoidDoubleTapSubmitRule',
      'avoid_double_tap_submit',
      () => AvoidDoubleTapSubmitRule(),
    );

    testRule(
      'PreferCursorForButtonsRule',
      'prefer_cursor_for_buttons',
      () => PreferCursorForButtonsRule(),
    );

    testRule(
      'RequireHoverStatesRule',
      'require_hover_states',
      () => RequireHoverStatesRule(),
    );

    testRule(
      'RequireButtonLoadingStateRule',
      'require_button_loading_state',
      () => RequireButtonLoadingStateRule(),
    );

    testRule(
      'AvoidHardcodedTextStylesRule',
      'avoid_hardcoded_text_styles',
      () => AvoidHardcodedTextStylesRule(),
    );

    testRule(
      'RequireRefreshIndicatorRule',
      'require_refresh_indicator',
      () => RequireRefreshIndicatorRule(),
    );

    testRule(
      'RequireDefaultTextStyleRule',
      'require_default_text_style',
      () => RequireDefaultTextStyleRule(),
    );

    testRule(
      'PreferAssetImageForLocalRule',
      'prefer_asset_image_for_local',
      () => PreferAssetImageForLocalRule(),
    );

    testRule(
      'PreferFitCoverForBackgroundRule',
      'prefer_fit_cover_for_background',
      () => PreferFitCoverForBackgroundRule(),
    );

    testRule(
      'RequireDisabledStateRule',
      'require_disabled_state',
      () => RequireDisabledStateRule(),
    );

    testRule(
      'RequireDragFeedbackRule',
      'require_drag_feedback',
      () => RequireDragFeedbackRule(),
    );

    testRule(
      'AvoidGestureConflictRule',
      'avoid_gesture_conflict',
      () => AvoidGestureConflictRule(),
    );

    testRule(
      'AvoidLargeImagesInMemoryRule',
      'avoid_large_images_in_memory',
      () => AvoidLargeImagesInMemoryRule(),
    );

    testRule(
      'PreferActionsAndShortcutsRule',
      'prefer_actions_and_shortcuts',
      () => PreferActionsAndShortcutsRule(),
    );

    testRule(
      'RequireLongPressCallbackRule',
      'require_long_press_callback',
      () => RequireLongPressCallbackRule(),
    );

    testRule(
      'AvoidFindChildInBuildRule',
      'avoid_find_child_in_build',
      () => AvoidFindChildInBuildRule(),
    );

    testRule(
      'RequireErrorWidgetRule',
      'require_error_widget',
      () => RequireErrorWidgetRule(),
    );

    testRule(
      'RequireFormValidationRule',
      'require_form_validation',
      () => RequireFormValidationRule(),
    );

    testRule(
      'RequireThemeColorFromSchemeRule',
      'require_theme_color_from_scheme',
      () => RequireThemeColorFromSchemeRule(),
    );

    testRule(
      'PreferColorSchemeFromSeedRule',
      'prefer_color_scheme_from_seed',
      () => PreferColorSchemeFromSeedRule(),
    );

    testRule(
      'PreferRichTextForComplexRule',
      'prefer_rich_text_for_complex',
      () => PreferRichTextForComplexRule(),
    );

    testRule(
      'PreferSystemThemeDefaultRule',
      'prefer_system_theme_default',
      () => PreferSystemThemeDefaultRule(),
    );

    testRule(
      'AvoidBrightnessCheckForThemeRule',
      'avoid_brightness_check_for_theme',
      () => AvoidBrightnessCheckForThemeRule(),
    );

    testRule(
      'RequireSafeAreaHandlingRule',
      'require_safe_area_handling',
      () => RequireSafeAreaHandlingRule(),
    );

    testRule(
      'PreferCupertinoForIosFeelRule',
      'prefer_cupertino_for_ios_feel',
      () => PreferCupertinoForIosFeelRule(),
    );

    testRule(
      'RequireWindowSizeConstraintsRule',
      'require_window_size_constraints',
      () => RequireWindowSizeConstraintsRule(),
    );

    testRule(
      'PreferKeyboardShortcutsRule',
      'prefer_keyboard_shortcuts',
      () => PreferKeyboardShortcutsRule(),
    );

    testRule(
      'AvoidNullableWidgetMethodsRule',
      'avoid_nullable_widget_methods',
      () => AvoidNullableWidgetMethodsRule(),
    );

    testRule(
      'PreferActionButtonTooltipRule',
      'prefer_action_button_tooltip',
      () => PreferActionButtonTooltipRule(),
    );

    testRule(
      'PreferVoidCallbackRule',
      'prefer_void_callback',
      () => PreferVoidCallbackRule(),
    );

    testRule(
      'RequireOrientationHandlingRule',
      'require_orientation_handling',
      () => RequireOrientationHandlingRule(),
    );

    testRule(
      'AvoidNavigationInBuildRule',
      'avoid_navigation_in_build',
      () => AvoidNavigationInBuildRule(),
    );

    testRule(
      'RequireTextFormFieldInFormRule',
      'require_text_form_field_in_form',
      () => RequireTextFormFieldInFormRule(),
    );

    testRule(
      'RequireWebViewNavigationDelegateRule',
      'require_webview_navigation_delegate',
      () => RequireWebViewNavigationDelegateRule(),
    );

    testRule(
      'RequireAnimatedBuilderChildRule',
      'require_animated_builder_child',
      () => RequireAnimatedBuilderChildRule(),
    );

    testRule(
      'RequireRethrowPreserveStackRule',
      'require_rethrow_preserve_stack',
      () => RequireRethrowPreserveStackRule(),
    );

    testRule(
      'RequireHttpsOverHttpRule',
      'require_https_over_http',
      () => RequireHttpsOverHttpRule(),
    );

    testRule(
      'RequireWssOverWsRule',
      'require_wss_over_ws',
      () => RequireWssOverWsRule(),
    );

    testRule(
      'AvoidLateWithoutGuaranteeRule',
      'avoid_late_without_guarantee',
      () => AvoidLateWithoutGuaranteeRule(),
    );

    testRule(
      'RequireImagePickerPermissionIosRule',
      'require_image_picker_permission_ios',
      () => RequireImagePickerPermissionIosRule(),
    );

    testRule(
      'RequireImagePickerPermissionAndroidRule',
      'require_image_picker_permission_android',
      () => RequireImagePickerPermissionAndroidRule(),
    );

    testRule(
      'RequirePermissionManifestAndroidRule',
      'require_permission_manifest_android',
      () => RequirePermissionManifestAndroidRule(),
    );

    testRule(
      'RequirePermissionPlistIosRule',
      'require_permission_plist_ios',
      () => RequirePermissionPlistIosRule(),
    );

    testRule(
      'RequireUrlLauncherQueriesAndroidRule',
      'require_url_launcher_queries_android',
      () => RequireUrlLauncherQueriesAndroidRule(),
    );

    testRule(
      'RequireUrlLauncherSchemesIosRule',
      'require_url_launcher_schemes_ios',
      () => RequireUrlLauncherSchemesIosRule(),
    );

    testRule(
      'AvoidStaticRouteConfigRule',
      'avoid_static_route_config',
      () => AvoidStaticRouteConfigRule(),
    );

    testRule(
      'RequireLocaleForTextRule',
      'require_locale_for_text',
      () => RequireLocaleForTextRule(),
    );

    testRule(
      'RequireDialogBarrierConsiderationRule',
      'require_dialog_barrier_consideration',
      () => RequireDialogBarrierConsiderationRule(),
    );

    testRule(
      'PreferFeatureFolderStructureRule',
      'prefer_feature_folder_structure',
      () => PreferFeatureFolderStructureRule(),
    );

    testRule(
      'AvoidBoolInWidgetConstructorsRule',
      'avoid_bool_in_widget_constructors',
      () => AvoidBoolInWidgetConstructorsRule(),
    );

    testRule(
      'AvoidUnnecessaryContainersRule',
      'avoid_unnecessary_containers',
      () => AvoidUnnecessaryContainersRule(),
    );

    testRule(
      'PreferConstLiteralsToCreateImmutablesRule',
      'prefer_const_literals_to_create_immutables',
      () => PreferConstLiteralsToCreateImmutablesRule(),
    );
  });

  group('Widget Patterns Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_bool_in_widget_constructors',
      'avoid_brightness_check_for_theme',
      'avoid_catching_generic_exception',
      'avoid_double_tap_submit',
      'avoid_duplicate_widget_keys',
      'avoid_empty_text_widgets',
      'avoid_find_child_in_build',
      'avoid_fitted_box_for_text',
      'avoid_font_weight_as_number',
      'avoid_form_without_key',
      'avoid_gesture_conflict',
      'avoid_gesture_without_behavior',
      'avoid_hardcoded_asset_paths',
      'avoid_hardcoded_text_styles',
      'avoid_icon_size_override',
      'avoid_image_repeat',
      'avoid_image_without_cache',
      'avoid_incorrect_image_opacity',
      'avoid_large_images_in_memory',
      'avoid_late_without_guarantee',
      'avoid_material2_fallback',
      'avoid_mediaquery_in_build',
      'avoid_missing_image_alt',
      'avoid_multiple_material_apps',
      'avoid_navigation_in_build',
      'avoid_navigator_push_without_route_name',
      'avoid_print_in_production',
      'avoid_nullable_widget_methods',
      'avoid_opacity_animation',
      'avoid_raw_keyboard_listener',
      'avoid_regex_in_loop',
      'avoid_static_route_config',
      'avoid_returning_widgets',
      'avoid_service_locator_overuse',
      'avoid_stateful_widget_in_list',
      'avoid_text_scale_factor',
      'avoid_uncontrolled_text_field',
      'avoid_unnecessary_gesture_detector',
      'avoid_unrestricted_text_field_length',
      'avoid_unnecessary_containers',
      'avoid_unused_callback_parameters',
      'prefer_action_button_tooltip',
      'prefer_actions_and_shortcuts',
      'prefer_asset_image_for_local',
      'prefer_cached_network_image',
      'prefer_carousel_view',
      'prefer_color_scheme_from_seed',
      'prefer_const_literals_to_create_immutables',
      'prefer_cupertino_for_ios_feel',
      'prefer_cursor_for_buttons',
      'prefer_define_hero_tag',
      'prefer_extracting_callbacks',
      'prefer_feature_folder_structure',
      'prefer_fit_cover_for_background',
      'prefer_getter_over_method',
      'prefer_inkwell_over_gesture',
      'prefer_keyboard_shortcuts',
      'prefer_overlay_portal',
      'prefer_rich_text_for_complex',
      'prefer_safe_area_consumer',
      'prefer_scaffold_messenger_maybeof',
      'prefer_search_anchor',
      'prefer_selectable_text',
      'prefer_semantic_widget_names',
      'prefer_single_widget_per_file',
      'prefer_split_widget_const',
      'prefer_system_theme_default',
      'prefer_tap_region_for_dismiss',
      'prefer_text_rich',
      'prefer_text_theme',
      'prefer_utc_datetimes',
      'prefer_void_callback',
      'prefer_widget_private_members',
      'require_animated_builder_child',
      'require_button_loading_state',
      'require_default_text_style',
      'require_disabled_state',
      'require_drag_feedback',
      'require_error_widget',
      'require_form_validation',
      'require_hover_states',
      'require_https_over_http',
      'require_image_dimensions',
      'require_image_error_builder',
      'require_image_picker_permission_android',
      'require_image_picker_permission_ios',
      'require_long_press_callback',
      'require_orientation_handling',
      'require_permission_manifest_android',
      'require_permission_plist_ios',
      'require_placeholder_for_network',
      'require_refresh_indicator',
      'require_rethrow_preserve_stack',
      'require_locale_for_text',
      'require_safe_area_handling',
      'require_text_form_field_in_form',
      'require_text_overflow_handling',
      'require_theme_color_from_scheme',
      'require_url_launcher_queries_android',
      'require_url_launcher_schemes_ios',
      'require_webview_navigation_delegate',
      'require_window_size_constraints',
      'require_wss_over_ws',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example/lib/widget_patterns/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior groups were removed. This file now keeps tests that
  // validate rule metadata and fixture presence instead of tautological asserts.
}
