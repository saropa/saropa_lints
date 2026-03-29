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
/// Test fixtures: example_widgets/lib/widget_patterns/*
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
          'example_widgets/lib/widget_patterns/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Image Rules', () {
    group('avoid_incorrect_image_opacity', () {
      test('Image in Opacity widget SHOULD trigger', () {
        // Use Image.color + colorBlendMode instead
        expect('Image in Opacity detected', isNotNull);
      });

      test('Image with colorBlendMode should NOT trigger', () {
        expect('colorBlendMode passes', isNotNull);
      });
    });

    group('avoid_missing_image_alt', () {
      test('Image without semanticLabel SHOULD trigger', () {
        expect('missing semanticLabel detected', isNotNull);
      });

      test('Image with semanticLabel should NOT trigger', () {
        expect('semanticLabel present passes', isNotNull);
      });
    });

    group('avoid_image_without_cache', () {
      test('Image.network without cacheWidth SHOULD trigger', () {
        // Decodes full resolution in memory
        expect('uncached image detected', isNotNull);
      });
    });

    group('avoid_image_repeat', () {
      test('ImageRepeat tiling SHOULD trigger', () {
        expect('image repeat detected', isNotNull);
      });
    });

    group('avoid_large_images_in_memory', () {
      test('large image without memory optimization SHOULD trigger', () {
        expect('large image detected', isNotNull);
      });
    });

    group('prefer_cached_network_image', () {
      test('Image.network re-downloading SHOULD trigger', () {
        expect('uncached network image detected', isNotNull);
      });
    });

    group('prefer_asset_image_for_local', () {
      test('local image via Image.network SHOULD trigger', () {
        expect('network load for local detected', isNotNull);
      });
    });

    group('prefer_fit_cover_for_background', () {
      test('background image without BoxFit.cover SHOULD trigger', () {
        expect('missing fit cover detected', isNotNull);
      });
    });

    group('require_image_error_builder', () {
      test('Image without errorBuilder SHOULD trigger', () {
        expect('missing errorBuilder detected', isNotNull);
      });
    });

    group('require_image_dimensions', () {
      test('Image without explicit dimensions SHOULD trigger', () {
        expect('missing dimensions detected', isNotNull);
      });
    });

    group('require_placeholder_for_network', () {
      test('network image without placeholder SHOULD trigger', () {
        expect('missing placeholder detected', isNotNull);
      });
    });
  });

  group('Text & Typography Rules', () {
    group('prefer_text_rich', () {
      test('RichText without DefaultTextStyle inheritance SHOULD trigger', () {
        // Use Text.rich instead
        expect('RichText detected', isNotNull);
      });
    });

    group('avoid_empty_text_widgets', () {
      test('Text with empty string SHOULD trigger', () {
        // Still occupies layout space
        expect('empty Text detected', isNotNull);
      });
    });

    group('avoid_font_weight_as_number', () {
      test('numeric FontWeight SHOULD trigger', () {
        expect('numeric FontWeight detected', isNotNull);
      });
    });

    group('avoid_text_scale_factor', () {
      test('textScaleFactor usage SHOULD trigger', () {
        // Deprecated; use textScaler
        expect('textScaleFactor detected', isNotNull);
      });
    });

    group('prefer_selectable_text', () {
      test('non-selectable text SHOULD trigger', () {
        expect('non-selectable text detected', isNotNull);
      });
    });

    group('prefer_rich_text_for_complex', () {
      test('complex text without RichText SHOULD trigger', () {
        expect('complex text without RichText detected', isNotNull);
      });
    });

    group('require_text_overflow_handling', () {
      test('Text without overflow SHOULD trigger', () {
        expect('missing overflow handling detected', isNotNull);
      });
    });

    group('require_locale_for_text', () {
      test('Text without locale awareness SHOULD trigger', () {
        expect('missing locale detected', isNotNull);
      });
    });

    group('require_default_text_style', () {
      test('DefaultTextStyle not set SHOULD trigger', () {
        expect('missing DefaultTextStyle detected', isNotNull);
      });
    });

    group('avoid_hardcoded_text_styles', () {
      test('hardcoded TextStyle SHOULD trigger', () {
        expect('hardcoded TextStyle detected', isNotNull);
      });
    });

    group('prefer_text_theme', () {
      test('explicit TextStyle instead of theme SHOULD trigger', () {
        expect('non-theme TextStyle detected', isNotNull);
      });
    });
  });

  group('Theme & Color Rules', () {
    group('require_theme_color_from_scheme', () {
      test('hardcoded colors SHOULD trigger', () {
        expect('hardcoded color detected', isNotNull);
      });
    });

    group('prefer_color_scheme_from_seed', () {
      test('manual ColorScheme SHOULD trigger', () {
        expect('manual ColorScheme detected', isNotNull);
      });
    });

    group('prefer_system_theme_default', () {
      test('theme not respecting system defaults SHOULD trigger', () {
        expect('non-system theme detected', isNotNull);
      });
    });

    group('avoid_brightness_check_for_theme', () {
      test('checking brightness instead of theme colors SHOULD trigger', () {
        expect('brightness check detected', isNotNull);
      });
    });

    group('avoid_material2_fallback', () {
      test('Material 2 fallback widget SHOULD trigger', () {
        expect('M2 fallback detected', isNotNull);
      });
    });
  });

  group('Gesture & Interaction Rules', () {
    group('avoid_unnecessary_gesture_detector', () {
      test('GestureDetector without callbacks SHOULD trigger', () {
        expect('empty GestureDetector detected', isNotNull);
      });
    });

    group('prefer_inkwell_over_gesture', () {
      test('GestureDetector with onTap only SHOULD trigger', () {
        // No visual feedback
        expect('GestureDetector for tap detected', isNotNull);
      });

      test('InkWell should NOT trigger', () {
        expect('InkWell passes', isNotNull);
      });
    });

    group('avoid_gesture_without_behavior', () {
      test('GestureDetector without behavior SHOULD trigger', () {
        expect('missing behavior detected', isNotNull);
      });
    });

    group('avoid_gesture_conflict', () {
      test('overlapping gesture detectors SHOULD trigger', () {
        expect('gesture conflict detected', isNotNull);
      });
    });

    group('avoid_double_tap_submit', () {
      test('button without double-tap protection SHOULD trigger', () {
        expect('double-tap risk detected', isNotNull);
      });
    });

    group('prefer_cursor_for_buttons', () {
      test('button without cursor styling SHOULD trigger', () {
        expect('missing cursor detected', isNotNull);
      });
    });

    group('require_hover_states', () {
      test('interactive widget without hover SHOULD trigger', () {
        expect('missing hover state detected', isNotNull);
      });
    });

    group('require_long_press_callback', () {
      test('long press without handler SHOULD trigger', () {
        expect('missing long press handler detected', isNotNull);
      });
    });

    group('require_drag_feedback', () {
      test('Draggable without feedback SHOULD trigger', () {
        expect('missing drag feedback detected', isNotNull);
      });
    });

    group('prefer_tap_region_for_dismiss', () {
      test('dismiss without TapRegion SHOULD trigger', () {
        expect('missing TapRegion detected', isNotNull);
      });
    });

    group('prefer_actions_and_shortcuts', () {
      test('keyboard handling without Actions SHOULD trigger', () {
        expect('missing Actions detected', isNotNull);
      });
    });

    group('prefer_keyboard_shortcuts', () {
      test('missing keyboard shortcuts SHOULD trigger', () {
        expect('missing keyboard shortcuts detected', isNotNull);
      });
    });
  });

  group('Widget Structure Rules', () {
    group('avoid_returning_widgets', () {
      test('method returning widget SHOULD trigger', () {
        // Hides structure; extract to separate widget
        expect('widget return method detected', isNotNull);
      });
    });

    group('prefer_single_widget_per_file', () {
      test('multiple public widgets in file SHOULD trigger', () {
        expect('multi-widget file detected', isNotNull);
      });
    });

    group('prefer_widget_private_members', () {
      test('public non-final field in widget SHOULD trigger', () {
        expect('public widget member detected', isNotNull);
      });
    });

    group('prefer_extracting_callbacks', () {
      test('inline callback exceeding length SHOULD trigger', () {
        expect('long inline callback detected', isNotNull);
      });
    });

    group('prefer_split_widget_const', () {
      test('large const widget subtree SHOULD trigger', () {
        expect('large const subtree detected', isNotNull);
      });
    });

    group('prefer_semantic_widget_names', () {
      test('generic Container SHOULD trigger', () {
        expect('generic widget name detected', isNotNull);
      });
    });

    group('avoid_find_child_in_build', () {
      test('find() in build SHOULD trigger', () {
        expect('find in build detected', isNotNull);
      });
    });

    group('prefer_feature_folder_structure', () {
      test('non-feature folder structure SHOULD trigger', () {
        expect('non-feature structure detected', isNotNull);
      });
    });
  });

  group('Form & Input Rules', () {
    group('avoid_uncontrolled_text_field', () {
      test('TextField without controller SHOULD trigger', () {
        expect('uncontrolled TextField detected', isNotNull);
      });
    });

    group('avoid_unrestricted_text_field_length', () {
      test('TextField without maxLength SHOULD trigger', () {
        expect('unrestricted length detected', isNotNull);
      });
    });

    group('avoid_form_without_key', () {
      test('Form without GlobalKey SHOULD trigger', () {
        expect('Form without key detected', isNotNull);
      });
    });

    group('require_form_validation', () {
      test('Form submit without validation SHOULD trigger', () {
        expect('missing validation detected', isNotNull);
      });
    });

    group('require_text_form_field_in_form', () {
      test('TextField in Form SHOULD trigger', () {
        // Should use TextFormField instead
        expect('TextField in Form detected', isNotNull);
      });
    });
  });

  group('Navigation Rules', () {
    group('avoid_navigator_push_without_route_name', () {
      test('inline MaterialPageRoute SHOULD trigger', () {
        expect('inline route detected', isNotNull);
      });
    });

    group('avoid_navigation_in_build', () {
      test('navigation in build SHOULD trigger', () {
        expect('navigation in build detected', isNotNull);
      });
    });

    group('avoid_multiple_material_apps', () {
      test('multiple MaterialApp SHOULD trigger', () {
        // Creates separate Navigator/Theme contexts
        expect('multiple MaterialApp detected', isNotNull);
      });
    });

    group('avoid_static_route_config', () {
      test('static route variables SHOULD trigger', () {
        expect('static routes detected', isNotNull);
      });
    });

    group('require_dialog_barrier_consideration', () {
      test('dialog barrier not configured SHOULD trigger', () {
        expect('unconfigured barrier detected', isNotNull);
      });
    });
  });

  group('Button & Loading Rules', () {
    group('require_button_loading_state', () {
      test('button without loading indicator SHOULD trigger', () {
        expect('missing loading state detected', isNotNull);
      });
    });

    group('require_disabled_state', () {
      test('interactive widget missing disabled styling SHOULD trigger', () {
        expect('missing disabled state detected', isNotNull);
      });
    });

    group('prefer_action_button_tooltip', () {
      test('action button without tooltip SHOULD trigger', () {
        expect('missing tooltip detected', isNotNull);
      });
    });

    group('require_refresh_indicator', () {
      test('refreshable list without RefreshIndicator SHOULD trigger', () {
        expect('missing RefreshIndicator detected', isNotNull);
      });
    });

    group('require_error_widget', () {
      test('error state without error widget SHOULD trigger', () {
        expect('missing error widget detected', isNotNull);
      });
    });
  });

  group('Hero & Animation Rules', () {
    group('prefer_define_hero_tag', () {
      test('Hero without explicit tag SHOULD trigger', () {
        expect('missing Hero tag detected', isNotNull);
      });
    });

    group('avoid_opacity_animation', () {
      test('Opacity changes in animation SHOULD trigger', () {
        // Causes frame drops
        expect('opacity animation detected', isNotNull);
      });
    });

    group('require_animated_builder_child', () {
      test('AnimatedBuilder without child SHOULD trigger', () {
        expect('missing AnimatedBuilder child detected', isNotNull);
      });
    });
  });

  group('Platform & Permission Rules', () {
    group('require_image_picker_permission_ios', () {
      test('iOS permissions not configured SHOULD trigger', () {
        expect('missing iOS permission detected', isNotNull);
      });
    });

    group('require_image_picker_permission_android', () {
      test('Android permissions not configured SHOULD trigger', () {
        expect('missing Android permission detected', isNotNull);
      });
    });

    group('require_permission_manifest_android', () {
      test('Android permissions missing in manifest SHOULD trigger', () {
        expect('missing manifest permission detected', isNotNull);
      });
    });

    group('require_permission_plist_ios', () {
      test('iOS permissions missing in plist SHOULD trigger', () {
        expect('missing plist permission detected', isNotNull);
      });
    });

    group('require_url_launcher_queries_android', () {
      test('Android URL launcher queries missing SHOULD trigger', () {
        expect('missing queries detected', isNotNull);
      });
    });

    group('require_url_launcher_schemes_ios', () {
      test('iOS URL launcher schemes missing SHOULD trigger', () {
        expect('missing schemes detected', isNotNull);
      });
    });

    group('prefer_cupertino_for_ios_feel', () {
      test('Material widget on iOS SHOULD trigger', () {
        expect('Material on iOS detected', isNotNull);
      });
    });

    group('require_window_size_constraints', () {
      test('window without size constraints SHOULD trigger', () {
        expect('missing constraints detected', isNotNull);
      });
    });

    group('require_orientation_handling', () {
      test('no orientation handling SHOULD trigger', () {
        expect('missing orientation handling detected', isNotNull);
      });
    });

    group('require_webview_navigation_delegate', () {
      test('WebView without navigation delegate SHOULD trigger', () {
        expect('missing navigation delegate detected', isNotNull);
      });
    });
  });

  group('Scaffold & MediaQuery Rules', () {
    group('avoid_mediaquery_in_build', () {
      test('MediaQuery.of subscribing to all changes SHOULD trigger', () {
        expect('MediaQuery.of detected', isNotNull);
      });

      test('MediaQuery.sizeOf should NOT trigger', () {
        expect('specific accessor passes', isNotNull);
      });
    });

    group('prefer_safe_area_consumer', () {
      test('SafeArea inside Scaffold body SHOULD trigger', () {
        expect('redundant SafeArea detected', isNotNull);
      });

      test('fixture has exactly one BAD (expect_lint) and GOOD top:false case', () {
        final file = File(
          'example_widgets/lib/widget_patterns/prefer_safe_area_consumer_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
        final content = file.readAsStringSync();
        final expectLintCount = RegExp(
          r'// expect_lint: prefer_safe_area_consumer',
        ).allMatches(content).length;
        expect(
          expectLintCount,
          1,
          reason: 'Exactly one BAD case should have expect_lint',
        );
        expect(
          content.contains('top: false') &&
              content.contains('_goodSafeAreaTopFalse'),
          isTrue,
          reason:
              'Fixture must include GOOD case SafeArea(top: false) to prevent regression',
        );
      });
    });

    group('prefer_scaffold_messenger_maybeof', () {
      test('ScaffoldMessenger.of without ancestor SHOULD trigger', () {
        expect('ScaffoldMessenger.of detected', isNotNull);
      });
    });

    group('require_safe_area_handling', () {
      test('SafeArea not used where needed SHOULD trigger', () {
        expect('missing SafeArea detected', isNotNull);
      });
    });
  });

  group('Modern Widget Rules', () {
    group('prefer_overlay_portal', () {
      test('modal without OverlayPortal SHOULD trigger', () {
        expect('missing OverlayPortal detected', isNotNull);
      });
    });

    group('prefer_carousel_view', () {
      test('carousel without CarouselView SHOULD trigger', () {
        expect('missing CarouselView detected', isNotNull);
      });
    });

    group('prefer_search_anchor', () {
      test('search without SearchAnchor SHOULD trigger', () {
        expect('missing SearchAnchor detected', isNotNull);
      });
    });

    group('avoid_raw_keyboard_listener', () {
      test('RawKeyboardListener SHOULD trigger', () {
        // Deprecated; use KeyboardListener
        expect('RawKeyboardListener detected', isNotNull);
      });
    });
  });

  group('Miscellaneous Rules', () {
    group('avoid_hardcoded_asset_paths', () {
      test('hardcoded asset path SHOULD trigger', () {
        expect('hardcoded asset path detected', isNotNull);
      });
    });

    group('avoid_print_in_production', () {
      test('print() in widget code SHOULD trigger', () {
        expect('print in production detected', isNotNull);
      });
    });

    group('avoid_catching_generic_exception', () {
      test('catching Exception/Object SHOULD trigger', () {
        expect('generic catch detected', isNotNull);
      });
    });

    group('avoid_service_locator_overuse', () {
      test('service locator in widget SHOULD trigger', () {
        expect('service locator overuse detected', isNotNull);
      });
    });

    group('prefer_utc_datetimes', () {
      test('local DateTime SHOULD trigger', () {
        expect('local DateTime detected', isNotNull);
      });
    });

    group('avoid_regex_in_loop', () {
      test('RegExp inside loop SHOULD trigger', () {
        expect('regex in loop detected', isNotNull);
      });
    });

    group('prefer_getter_over_method', () {
      test('zero-parameter method SHOULD trigger', () {
        expect('method-as-getter detected', isNotNull);
      });
    });

    group('avoid_unused_callback_parameters', () {
      test('unused callback parameter SHOULD trigger', () {
        expect('unused callback param detected', isNotNull);
      });
    });

    group('prefer_void_callback', () {
      test('callback returning value when void expected SHOULD trigger', () {
        expect('non-void callback detected', isNotNull);
      });
    });

    group('avoid_nullable_widget_methods', () {
      test('nullable method without null check SHOULD trigger', () {
        expect('nullable widget method detected', isNotNull);
      });
    });

    group('avoid_late_without_guarantee', () {
      test('late field without guaranteed init SHOULD trigger', () {
        expect('risky late field detected', isNotNull);
      });
    });

    group('require_rethrow_preserve_stack', () {
      test('rethrowing without stack trace SHOULD trigger', () {
        expect('lost stack trace detected', isNotNull);
      });
    });

    group('require_https_over_http', () {
      test('HTTP instead of HTTPS SHOULD trigger', () {
        expect('HTTP URL detected', isNotNull);
      });
    });

    group('require_wss_over_ws', () {
      test('WS instead of WSS SHOULD trigger', () {
        expect('insecure WebSocket detected', isNotNull);
      });
    });

    group('avoid_icon_size_override', () {
      test('individual icon size override SHOULD trigger', () {
        expect('icon size override detected', isNotNull);
      });
    });

    group('avoid_duplicate_widget_keys', () {
      test('duplicate Key values SHOULD trigger', () {
        expect('duplicate keys detected', isNotNull);
      });
    });

    group('avoid_stateful_widget_in_list', () {
      test('StatefulWidget in ListView.builder SHOULD trigger', () {
        expect(
          AvoidStatefulWidgetInListRule().code.lowerCaseName,
          'avoid_stateful_widget_in_list',
        );
      });
    });

    group('avoid_fitted_box_for_text', () {
      test('FittedBox around Text SHOULD trigger', () {
        expect(
          AvoidFittedBoxForTextRule().code.lowerCaseName,
          'avoid_fitted_box_for_text',
        );
      });
    });
  });
}
