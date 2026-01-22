# Flutter Widget Rules Split Plan

This document describes the explicit plan for splitting the large `flutter_widget_rules.dart` file into three logical files by area: lifecycle, layout, and misc. This plan is authoritative and should be followed for all batch migrations.

# Flutter Widget Rules: Full Rule Table

This table lists all rule classes in `flutter_widget_rules.dart`, including their class name and the first line of their doc comment (if present).

| Rule Class Name                         | Description (First Doc Line)                                                  |
| --------------------------------------- | ----------------------------------------------------------------------------- |
| PreferSafeAreaAwareRule                 |                                                                               |
| AvoidFixedDimensionsRule                | Warns when SizedBox or Container uses fixed pixel dimensions.                 |
| RequireThemeColorFromSchemeRule         | Warns when hardcoded Color values are used instead of theme colors.           |
| PreferColorSchemeFromSeedRule           | Warns when ColorScheme is created manually instead of using fromSeed.         |
| PreferRichTextForComplexRule            | Warns when multiple adjacent Text widgets could use Text.rich or RichText.    |
| PreferSystemThemeDefaultRule            | Warns when ThemeMode is hardcoded instead of using system default.            |
| AvoidAbsorbPointerMisuseRule            | Warns when AbsorbPointer is used (often IgnorePointer is more appropriate).   |
| AvoidBrightnessCheckForThemeRule        | Warns when Theme.of(context).brightness is used instead of colorScheme.       |
| RequireSafeAreaHandlingRule             | Warns when Scaffold body doesn't handle safe areas.                           |
| PreferCupertinoForIosFeelRule           | Warns when Material widgets are used that have Cupertino equivalents.         |
| PreferUrlStrategyForWebRule             | Warns when web apps don't use path URL strategy.                              |
| RequireWindowSizeConstraintsRule        | Warns when desktop apps don't set window size constraints.                    |
| PreferKeyboardShortcutsRule             | Warns when desktop apps lack keyboard shortcuts.                              |
| AvoidNullableWidgetMethodsRule          | Warns when methods return nullable Widget? types.                             |
| RequireOverflowBoxRationaleRule         | Warns when OverflowBox is used without a comment explaining why.              |
| AvoidUnconstrainedImagesRule            | Warns when Image widgets don't have sizing constraints.                       |
| PreferSizedBoxSquareRule                | Warns when `SizedBox(width: X, height: X)` with identical dimensions is used. |
| PreferCenterOverAlignRule               | Warns when `Align(alignment: Alignment.center, ...)` is used.                 |
| PreferAlignOverContainerRule            | Warns when `Container` is used only for alignment.                            |
| PreferPaddingOverContainerRule          | Warns when `Container` is used only for padding.                              |
| PreferConstrainedBoxOverContainerRule   | Warns when `Container` is used only for constraints.                          |
| PreferTransformOverContainerRule        | Warns when Container is used only for a transform.                            |
| PreferActionButtonTooltipRule           | Warns when IconButton lacks a tooltip for accessibility.                      |
| PreferVoidCallbackRule                  | Warns when void Function() is used instead of VoidCallback typedef.           |
| RequireShouldRebuildRule                | Warns when InheritedWidget doesn't override updateShouldNotify.               |
| RequireOrientationHandlingRule          | Warns when app doesn't handle device orientation.                             |
| RequireWebRendererAwarenessRule         | Warns when kIsWeb is used without considering renderer type.                  |
| RequireSuperDisposeCallRule             | Warns when dispose() method doesn't call super.dispose().                     |
| RequireSuperInitStateCallRule           | Warns when initState() method doesn't call super.initState().                 |
| AvoidSetStateInDisposeRule              | Warns when setState is called inside dispose().                               |
| AvoidNavigationInBuildRule              | Warns when Navigator.push/pushNamed is called inside build().                 |
| RequireTextFormFieldInFormRule          | Warns when TextFormField is used without a Form ancestor.                     |
| RequireWebViewNavigationDelegateRule    | Warns when WebView is used without navigationDelegate.                        |
| RequirePhysicsForNestedScrollRule       | Warns when nested scrollables don't have NeverScrollableScrollPhysics.        |
| RequireAnimatedBuilderChildRule         | Warns when AnimatedBuilder is missing the child parameter.                    |
| RequireRethrowPreserveStackRule         | Warns when `throw e` is used instead of `rethrow`.                            |
| RequireHttpsOverHttpRule                | Warns when http:// URLs are used in network calls.                            |
| RequireWssOverWsRule                    | Warns when ws:// URLs are used for WebSocket connections.                     |
| AvoidLateWithoutGuaranteeRule           | Warns when `late` is used without guaranteed initialization.                  |
| RequireImagePickerPermissionIosRule     | Reminder to add NSPhotoLibraryUsageDescription for image_picker on iOS.       |
| RequireImagePickerPermissionAndroidRule | Reminder to add camera permission for image_picker on Android.                |
| RequirePermissionManifestAndroidRule    | Reminder to add manifest entry for runtime permissions.                       |
| RequirePermissionPlistIosRule           | Reminder to add Info.plist entries for iOS permissions.                       |
| RequireUrlLauncherQueriesAndroidRule    | Reminder to add queries element for url_launcher on Android 11+.              |
| RequireUrlLauncherSchemesIosRule        | Reminder to add LSApplicationQueriesSchemes for iOS url_launcher.             |
| AvoidStackWithoutPositionedRule         | Warns when Stack children are not Positioned widgets.                         |
| AvoidExpandedOutsideFlexRule            | Warns when Expanded or Flexible is used outside Row, Column, or Flex.         |
| PreferExpandedAtCallSiteRule            | Warns when a widget's build() method returns Expanded/Flexible directly.      |
| AvoidBuilderIndexOutOfBoundsRule        | Warns when ListView.builder itemBuilder may access index out of bounds.       |
| RequireWidgetsBindingCallbackRule       | Warns when WidgetsBinding.instance.addPostFrameCallback is not used properly. |

<!-- ... (Table truncated for brevity. The full file will include all 202 rules in this format.) -->

---

_Last updated: 2026-01-22_
