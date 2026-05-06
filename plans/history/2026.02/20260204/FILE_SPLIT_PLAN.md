# File Split Plan: Large Rule Files

## Overview

Five rule files have grown beyond manageable size. This plan breaks them into
smaller, focused files targeting **15-25 rules each** (consistent with the
existing codebase where files average 13-34 rules).

### Current State

| File | Rules | Lines |
|------|------:|------:|
| `widget_patterns_rules.dart` | 103 | 8,331 |
| `code_quality_rules.dart` | 103 | 8,376 |
| `widget_layout_rules.dart` | 73 | 7,985 |
| `security_rules.dart` | 53 | 6,420 |
| `async_rules.dart` | 46 | 4,717 |
| **Total** | **378** | **35,829** |

### Naming Conflicts

These existing files overlap in domain with proposed splits. Each section notes
whether to **merge into** the existing file or use a distinct name.

| Existing file | Rules | Could absorb from |
|---------------|------:|-------------------|
| `image_rules.dart` | 19 | widget_patterns image rules |
| `scroll_rules.dart` | 13 | widget_layout scrollable rules |
| `navigation_rules.dart` | 34 | widget_patterns navigation rules |
| `forms_rules.dart` | 23 | widget_patterns form rules |
| `control_flow_rules.dart` | 28 | code_quality control flow rules |
| `collection_rules.dart` | 23 | code_quality enum/collection rules |
| `type_safety_rules.dart` | 16 | code_quality type system rules |

---

## Phase 1: `widget_patterns_rules.dart` (103 rules -> 7 files)

Delete `widget_patterns_rules.dart` after all rules are relocated.

### 1a. Merge into `image_rules.dart` (existing: 19, adding: 11 = 30)

Move these 11 image/media rules into the existing file:

- `AvoidIncorrectImageOpacityRule`
- `AvoidMissingImageAltRule`
- `AvoidImageWithoutCacheRule`
- `RequireImageErrorBuilderRule`
- `RequireImageDimensionsRule`
- `RequirePlaceholderForNetworkRule`
- `PreferCachedNetworkImageRule`
- `AvoidImageRepeatRule`
- `AvoidLargeImagesInMemoryRule`
- `PreferAssetImageForLocalRule`
- `PreferFitCoverForBackgroundRule`

### 1b. NEW `widget_text_rules.dart` (9 rules)

Typography, text styling, and text widget patterns:

- `PreferTextRichRule`
- `AvoidTextScaleFactorRule`
- `AvoidFontWeightAsNumberRule`
- `AvoidFittedBoxForTextRule`
- `PreferSelectableTextRule`
- `RequireTextOverflowHandlingRule`
- `PreferTextThemeRule`
- `AvoidHardcodedTextStylesRule`
- `PreferRichTextForComplexRule`

### 1c. NEW `widget_gesture_rules.dart` (10 rules)

Touch, tap, drag, and gesture-related patterns:

- `AvoidUnnecessaryGestureDetectorRule`
- `PreferInkwellOverGestureRule`
- `AvoidGestureWithoutBehaviorRule`
- `AvoidDoubleTapSubmitRule`
- `AvoidGestureConflictRule`
- `RequireHoverStatesRule`
- `RequireDragFeedbackRule`
- `RequireLongPressCallbackRule`
- `PreferActionsAndShortcutsRule`
- `PreferTapRegionForDismissRule`

### 1d. Merge into `forms_rules.dart` (existing: 23, adding: 7 = 30)

Move these form/input rules into the existing file:

- `AvoidUncontrolledTextFieldRule`
- `AvoidUnrestrictedTextFieldLengthRule`
- `AvoidFormWithoutKeyRule`
- `RequireFormValidationRule`
- `RequireTextFormFieldInFormRule`
- `RequireDefaultTextStyleRule`
- `RequireButtonLoadingStateRule`

### 1e. Merge into `navigation_rules.dart` (existing: 34, adding: 6 = 40)

> **Note:** 40 rules is high. Consider further splitting `navigation_rules.dart`
> later, or only merge a subset.

Move these navigation/routing rules into the existing file:

- `PreferDefineHeroTagRule`
- `AvoidNavigatorPushWithoutRouteNameRule`
- `PreferScaffoldMessengerMaybeOfRule`
- `AvoidDialogContextAfterAsyncRule`
- `RequireDialogBarrierConsiderationRule`
- `RequireWebViewNavigationDelegateRule`

### 1f. NEW `widget_theme_rules.dart` (10 rules)

Theming, color schemes, Material Design patterns:

- `RequireThemeColorFromSchemeRule`
- `PreferColorSchemeFromSeedRule`
- `PreferSystemThemeDefaultRule`
- `AvoidBrightnessCheckForThemeRule`
- `RequireDisabledStateRule`
- `PreferActionButtonTooltipRule`
- `PreferCursorForButtonsRule`
- `AvoidMaterial2FallbackRule`
- `AvoidIconSizeOverrideRule`
- `RequireLocaleForTextRule`

### 1g. NEW `widget_architecture_rules.dart` (17 rules)

Widget design, composition, and structural patterns:

- `AvoidReturningWidgetsRule`
- `PreferExtractingCallbacksRule`
- `PreferSingleWidgetPerFileRule`
- `PreferWidgetPrivateMembersRule`
- `PreferSemanticWidgetNamesRule`
- `PreferSplitWidgetConstRule`
- `AvoidNullableWidgetMethodsRule`
- `PreferVoidCallbackRule`
- `AvoidStatefulWidgetInListRule`
- `AvoidEmptyTextWidgetsRule`
- `AvoidMultipleMaterialAppsRule`
- `RequireErrorWidgetRule`
- `AvoidFindChildInBuildRule`
- `AvoidNavigationInBuildRule`
- `AvoidStaticRouteConfigRule`
- `PreferFeatureFolderStructureRule`
- `AvoidLateWithoutGuaranteeRule`

### 1h. NEW `widget_platform_rules.dart` (20 rules)

Platform APIs, modern widget replacements, and platform configuration:

- `PreferOverlayPortalRule`
- `PreferCarouselViewRule`
- `PreferSearchAnchorRule`
- `AvoidRawKeyboardListenerRule`
- `PreferCupertinoForIosFeelRule`
- `RequireWindowSizeConstraintsRule`
- `PreferKeyboardShortcutsRule`
- `RequireOrientationHandlingRule`
- `RequireSafeAreaHandlingRule`
- `PreferSafeAreaConsumerRule`
- `RequireAnimatedBuilderChildRule`
- `AvoidOpacityAnimationRule`
- `RequireImagePickerPermissionIosRule`
- `RequireImagePickerPermissionAndroidRule`
- `RequirePermissionManifestAndroidRule`
- `RequirePermissionPlistIosRule`
- `RequireUrlLauncherQueriesAndroidRule`
- `RequireUrlLauncherSchemesIosRule`

### 1i. Remaining miscellaneous rules (13 rules)

Relocate to existing files by domain:

| Rule | Target file |
|------|-------------|
| `AvoidHardcodedAssetPathsRule` | `config_rules.dart` |
| `AvoidPrintInProductionRule` | `debug_rules.dart` |
| `AvoidCatchingGenericExceptionRule` | `error_handling_rules.dart` |
| `AvoidServiceLocatorOveruseRule` | `dependency_injection_rules.dart` |
| `PreferUtcDateTimesRule` | `json_datetime_rules.dart` |
| `AvoidRegexInLoopRule` | `performance_rules.dart` |
| `PreferGetterOverMethodRule` | `structure_rules.dart` |
| `AvoidUnusedCallbackParametersRule` | `structure_rules.dart` |
| `AvoidDuplicateWidgetKeysRule` | `widget_lifecycle_rules.dart` |
| `AvoidMediaQueryInBuildRule` | `build_method_rules.dart` |
| `RequireRefreshIndicatorRule` | `scroll_rules.dart` |
| `RequireHttpsOverHttpRule` | `security_rules.dart` |
| `RequireWssOverWsRule` | `security_rules.dart` |
| `RequireRethrowPreserveStackRule` | `error_handling_rules.dart` |

---

## Phase 2: `code_quality_rules.dart` (103 rules -> 7 files)

Delete `code_quality_rules.dart` after all rules are relocated.

### 2a. NEW `string_rules.dart` (7 rules)

String manipulation and literal patterns:

- `AvoidAdjacentStringsRule`
- `AvoidSubstringRule`
- `AvoidDefaultToStringRule`
- `AvoidDuplicateStringLiteralsRule`
- `AvoidDuplicateStringLiteralsPairRule`
- `PreferUsePrefixRule`
- `PreferTypesdefsForCallbacksRule`

### 2b. NEW `enum_switch_rules.dart` (10 rules)

Enum usage and pattern matching / switch:

- `AvoidEnumValuesByIndexRule`
- `PreferEnumsByNameRule`
- `AvoidMissingEnumConstantInMapRule`
- `AvoidWildcardCasesWithEnumsRule`
- `AvoidWildcardCasesWithSealedClassesRule`
- `AvoidDuplicatePatternsRule`
- `AvoidUnnecessaryPatternsRule`
- `NoEqualSwitchCaseRule`
- `NoEqualSwitchExpressionCasesRule`
- `PreferSwitchExpressionRule`

### 2c. NEW `switch_shorthand_rules.dart` (9 rules)

Switch patterns and shorthand preferences:

- `PreferSwitchWithEnumsRule`
- `PreferSwitchWithSealedClassesRule`
- `PreferSpecificCasesFirstRule`
- `PreferShorthandsWithConstructorsRule`
- `PreferShorthandsWithEnumsRule`
- `PreferShorthandsWithStaticFieldsRule`
- `PreferDotShorthandRule`
- `AvoidAccessingCollectionsByConstantIndexRule`
- `AvoidSlowCollectionMethodsRule`

### 2d. Merge into `type_safety_rules.dart` (existing: 16, adding: 11 = 27)

Move these type system rules into the existing file:

- `AvoidIncorrectUriRule`
- `AvoidMisusedSetLiteralsRule`
- `NoObjectDeclarationRule`
- `PassCorrectAcceptedTypeRule`
- `PreferInferredTypeArgumentsRule`
- `AvoidInferrableTypeArgumentsRule`
- `PreferUnwrappingFutureOrRule`
- `PreferTypedDataRule`
- `AvoidNestedExtensionTypesRule`
- `AvoidShadowedExtensionMethodsRule`
- `PreferBytesBuilderRule`

### 2e. NEW `parameter_rules.dart` (11 rules)

Parameter and argument handling:

- `AvoidPassingSelfAsArgumentRule`
- `AvoidUnusedParametersRule`
- `AvoidAlwaysNullParametersRule`
- `AvoidUnnecessaryNullableParametersRule`
- `AvoidParameterReassignmentRule`
- `AvoidParameterMutationRule`
- `PassOptionalArgumentRule`
- `MatchBaseClassDefaultValueRule`
- `AvoidPassingDefaultValuesRule`
- `PreferRedirectingSuperclassConstructorRule`
- `PreferOverridingParentEqualityRule`

### 2f. NEW `variable_rules.dart` (19 rules)

Variable assignment, late/nullable, and scoping:

- `AvoidReferencingDiscardedVariablesRule`
- `AvoidAssigningToStaticFieldRule`
- `AvoidLateFinalReassignmentRule`
- `AvoidUnassignedFieldsRule`
- `AvoidUnassignedLateFieldsRule`
- `AvoidUnnecessaryLateFieldsRule`
- `AvoidUnnecessaryNullableFieldsRule`
- `AvoidUnusedAssignmentRule`
- `AvoidUnusedInstancesRule`
- `AvoidUnusedAfterNullCheckRule`
- `MoveVariableCloserToUsageRule`
- `MoveVariableOutsideIterationRule`
- `UseExistingDestructuringRule`
- `UseExistingVariableRule`
- `AvoidUnnecessaryLocalLateRule`
- `AvoidLateKeywordRule`
- `PreferLateFinalRule`
- `AvoidLateForNullableRule`
- `PreferNullAwareSpreadRule`

### 2g. Merge into `control_flow_rules.dart` (existing: 28, adding: 15 = 43)

> **Note:** 43 rules is high. Consider splitting `control_flow_rules.dart` into
> `control_flow_rules.dart` + `conditional_rules.dart` in a later phase.

Move these control flow rules into the existing file:

- `AvoidRecursiveCallsRule`
- `AvoidRecursiveToStringRule`
- `AvoidAsyncCallInSyncFunctionRule`
- `AvoidComplexLoopConditionsRule`
- `AvoidConstantConditionsRule`
- `AvoidContradictoryExpressionsRule`
- `AvoidIdenticalExceptionHandlingBlocksRule`
- `NoEqualNestedConditionsRule`
- `PreferAnyOrEveryRule`
- `PreferForInRule`
- `PreferPushingConditionalExpressionsRule`
- `NoBooleanLiteralCompareRule`
- `PreferReturningConditionalExpressionsRule`
- `AvoidSimilarNamesRule`
- `AvoidUnnecessaryToListRule`

### 2h. Remaining miscellaneous rules (21 rules)

Relocate to existing files by domain:

| Rule | Target file |
|------|-------------|
| `FunctionAlwaysReturnsNullRule` | `return_rules.dart` |
| `FunctionAlwaysReturnsSameValueRule` | `return_rules.dart` |
| `PreferExtractingFunctionCallbacksRule` | `structure_rules.dart` |
| `AvoidMissedCallsRule` | `structure_rules.dart` |
| `AvoidDuplicateConstantValuesRule` | `unnecessary_code_rules.dart` |
| `AvoidDuplicateInitializersRule` | `unnecessary_code_rules.dart` |
| `AvoidUnnecessaryOverridesRule` | `unnecessary_code_rules.dart` |
| `AvoidUnnecessaryStatementsRule` | `unnecessary_code_rules.dart` |
| `AvoidRedundantPragmaInlineRule` | `performance_rules.dart` |
| `PreferBothInliningAnnotationsRule` | `performance_rules.dart` |
| `AvoidUnknownPragmaRule` | `structure_rules.dart` |
| `AvoidEmptyBuildWhenRule` | `build_method_rules.dart` |
| `AvoidIgnoreTrailingCommentRule` | `stylistic_rules.dart` |
| `MissingUseResultAnnotationRule` | `structure_rules.dart` |
| `AvoidWeakCryptographicAlgorithmsRule` | `crypto_rules.dart` |
| `AvoidMissingCompleterStackTraceRule` | `async_rules.dart` |
| `PreferTestMatchersRule` | `test_rules.dart` |
| `PreferVisibleForTestingOnMembersRule` | `test_rules.dart` |
| `PreferDedicatedMediaQueryMethodRule` | `media_rules.dart` |
| `PreferSingleDeclarationPerFileRule` | `structure_rules.dart` |

---

## Phase 3: `widget_layout_rules.dart` (73 rules -> 6 files)

Delete `widget_layout_rules.dart` after all rules are relocated.

### 3a. NEW `flex_rules.dart` (7 rules)

Column, Row, Flex, Expanded, Flexible patterns:

- `AvoidExpandedAsSpacerRule`
- `AvoidFlexibleOutsideFlexRule`
- `AvoidExpandedOutsideFlexRule`
- `AvoidSingleChildColumnRowRule`
- `PreferExpandedAtCallSiteRule`
- `PreferSpacingOverSizedBoxRule`
- `AvoidSpacerInWrapRule`

### 3b. Merge into `scroll_rules.dart` (existing: 13, adding: 16 = 29)

Move these scrollable widget rules into the existing file:

- `AvoidShrinkWrapInListsRule`
- `PreferUsingListViewRule`
- `AvoidListViewWithoutItemExtentRule`
- `PreferSliverListDelegateRule`
- `AvoidSingleChildScrollViewWithColumnRule`
- `AvoidGestureDetectorInScrollViewRule`
- `PreferListViewBuilderRule`
- `AvoidNestedScrollablesRule`
- `RequireScrollPhysicsRule`
- `PreferSliverListRule`
- `AvoidLayoutBuilderInScrollableRule`
- `RequireScrollControllerRule`
- `AvoidShrinkWrapInScrollRule`
- `RequirePhysicsForNestedScrollRule`
- `AvoidScrollableInIntrinsicRule`
- `AvoidUnboundedListviewInColumnRule`

### 3c. NEW `sliver_rules.dart` (4 rules)

Sliver-specific patterns:

- `PreferSliverPrefixRule`
- `PreferSliverAppBarRule`
- `PreferKeepAliveRule`
- `PreferPageStorageKeyRule`

### 3d. NEW `sizing_rules.dart` (16 rules)

Sizing, constraints, padding, and spacing:

- `AvoidWrappingInPaddingRule`
- `PreferSizedBoxForWhitespaceRule`
- `AvoidSizedBoxExpandRule`
- `AvoidUnboundedConstraintsRule`
- `PreferFractionalSizingRule`
- `AvoidUnconstrainedBoxMisuseRule`
- `AvoidFixedDimensionsRule`
- `AvoidUnconstrainedImagesRule`
- `PreferSizedBoxSquareRule`
- `AvoidHardcodedLayoutValuesRule`
- `RequireOverflowBoxRationaleRule`
- `AvoidUnconstrainedDialogColumnRule`
- `AvoidFixedSizeInScaffoldBodyRule`
- `AvoidMisnamedPaddingRule`
- `PreferConstBorderRadiusRule`
- `PreferCorrectEdgeInsetsConstructorRule`

### 3e. NEW `container_rules.dart` (5 rules)

Container alternatives and preferences:

- `PreferCenterOverAlignRule`
- `PreferAlignOverContainerRule`
- `PreferPaddingOverContainerRule`
- `PreferConstrainedBoxOverContainerRule`
- `PreferTransformOverContainerRule`

### 3f. Remaining layout rules (25 rules)

Relocate to existing or new files by domain:

| Rule | Target file |
|------|-------------|
| `CheckForEqualsInRenderObjectSettersRule` | `performance_rules.dart` |
| `ConsistentUpdateRenderObjectRule` | `widget_lifecycle_rules.dart` |
| `AvoidBorderAllRule` | `performance_rules.dart` |
| `AvoidDeeplyNestedWidgetsRule` | `complexity_rules.dart` |
| `PreferConstWidgetsInListsRule` | `performance_rules.dart` |
| `AvoidDeepWidgetNestingRule` | `complexity_rules.dart` |
| `AvoidLayoutBuilderMisuseRule` | `build_method_rules.dart` |
| `AvoidRepaintBoundaryMisuseRule` | `performance_rules.dart` |
| `PreferOpacityWidgetRule` | `performance_rules.dart` |
| `AvoidOpacityMisuseRule` | `performance_rules.dart` |
| `PreferIntrinsicDimensionsRule` | `sizing_rules.dart` (new) |
| `AvoidAbsorbPointerMisuseRule` | `widget_gesture_rules.dart` (new) |
| `PreferCustomSingleChildLayoutRule` | `sizing_rules.dart` (new) |
| `AvoidNestedScaffoldsRule` | `widget_architecture_rules.dart` (new) |
| `AvoidStackWithoutPositionedRule` | `widget_architecture_rules.dart` (new) |
| `PreferPositionedDirectionalRule` | `internationalization_rules.dart` |
| `AvoidPositionedOutsideStackRule` | `widget_architecture_rules.dart` (new) |
| `PreferSafeAreaAwareRule` | `widget_platform_rules.dart` (new) |
| `RequireBaselineTextBaselineRule` | `widget_text_rules.dart` (new) |
| `PreferWrapOverOverflowRule` | `flex_rules.dart` (new) |
| `PreferClipBehaviorRule` | `performance_rules.dart` |
| `PreferIgnorePointerRule` | `widget_gesture_rules.dart` (new) |
| `AvoidBuilderIndexOutOfBoundsRule` | `build_method_rules.dart` |
| `AvoidTableCellOutsideTableRule` | `widget_architecture_rules.dart` (new) |
| `AvoidTextfieldInRowRule` | `flex_rules.dart` (new) |

---

## Phase 4: `security_rules.dart` (53 rules -> 5 files)

Delete `security_rules.dart` after all rules are relocated.

### 4a. NEW `secure_storage_rules.dart` (12 rules)

Secure storage, encryption, and data-at-rest:

- `RequireSecureStorageRule`
- `RequireSecureStorageForAuthRule`
- `RequireSecureStorageAuthDataRule`
- `RequireSecureStorageErrorHandlingRule`
- `AvoidSecureStorageLargeDataRule`
- `AvoidStoringSensitiveUnencryptedRule`
- `AvoidExternalStorageSensitiveRule`
- `RequireDataEncryptionRule`
- `AvoidEncryptionKeyInMemoryRule`
- `AvoidLoggingSensitiveDataRule`
- `RequireCatchLoggingRule`
- `AvoidSensitiveDataInClipboardRule`

### 4b. NEW `credential_rules.dart` (9 rules)

Credentials, auth tokens, and authentication:

- `AvoidHardcodedCredentialsRule`
- `AvoidStoringPasswordsRule`
- `AvoidApiKeyInCodeRule`
- `RequireAuthCheckRule`
- `RequireTokenRefreshRule`
- `AvoidJwtDecodeClientRule`
- `RequireLogoutCleanupRule`
- `AvoidAuthInQueryParamsRule`
- `RequireBiometricFallbackRule`

### 4c. NEW `network_security_rules.dart` (8 rules)

Network security, TLS, certificate pinning:

- `RequireCertificatePinningRule`
- `AvoidTokenInUrlRule`
- `AvoidGenericKeyInUrlRule`
- `AvoidUserControlledUrlsRule`
- `AvoidRedirectInjectionRule`
- `AvoidIgnoringSslErrorsRule`
- `RequireHttpsOnlyRule`
- `RequireHttpsOnlyTestRule`

### 4d. NEW `input_validation_rules.dart` (6 rules)

Input sanitization, SQL injection, path traversal:

- `RequireInputSanitizationRule`
- `AvoidDynamicSqlRule`
- `AvoidPathTraversalRule`
- `PreferHtmlEscapeRule`
- `RequireUrlValidationRule`
- `RequireClipboardPasteValidationRule`

### 4e. Remaining security rules (18 rules)

Relocate to existing or new files by domain:

| Rule | Target file |
|------|-------------|
| `AvoidWebViewJavaScriptEnabledRule` | `navigation_rules.dart` |
| `PreferWebViewJavaScriptDisabledRule` | `navigation_rules.dart` |
| `AvoidWebViewInsecureContentRule` | `navigation_rules.dart` |
| `RequireWebViewErrorHandlingRule` | `navigation_rules.dart` |
| `AvoidEvalLikePatternsRule` | `input_validation_rules.dart` (new) |
| `AvoidDynamicCodeLoadingRule` | `input_validation_rules.dart` (new) |
| `AvoidUnverifiedNativeLibraryRule` | `platform_rules.dart` |
| `AvoidUnsafeDeserializationRule` | `input_validation_rules.dart` (new) |
| `PreferSecureRandomRule` | `crypto_rules.dart` |
| `AvoidHardcodedSigningConfigRule` | `config_rules.dart` |
| `RequireDeepLinkValidationRule` | `navigation_rules.dart` |
| `PreferDataMaskingRule` | `ui_ux_rules.dart` |
| `AvoidScreenshotSensitiveRule` | `platform_rules.dart` |
| `RequireSecurePasswordFieldRule` | `forms_rules.dart` |
| `AvoidClipboardSensitiveRule` | `secure_storage_rules.dart` (new) |
| `PreferLocalAuthRule` | `credential_rules.dart` (new) |

---

## Phase 5: `async_rules.dart` (46 rules -> 4 files)

Delete `async_rules.dart` after all rules are relocated.

### 5a. NEW `future_rules.dart` (12 rules)

Future misuse, patterns, and best practices:

- `AvoidFutureIgnoreRule`
- `AvoidFutureToStringRule`
- `AvoidNestedFuturesRule`
- `AvoidRedundantAsyncRule`
- `PreferAsyncAwaitRule`
- `PreferAssigningAwaitExpressionsRule`
- `PreferCommentingFutureDelayedRule`
- `PreferCorrectFutureReturnTypeRule`
- `PreferSpecifyingFutureValueTypeRule`
- `PreferReturnAwaitRule`
- `AvoidUnawaitedFutureRule`
- `PreferFutureWaitRule`

### 5b. NEW `stream_rules2.dart` (10 rules)

> Named `stream_rules2.dart` to avoid conflict with existing `scroll_rules.dart`.
> Alternatively, merge into `scroll_rules.dart` if it gets renamed.
>
> **Better alternative:** Rename existing `scroll_rules.dart` to
> `scroll_view_rules.dart` and use `stream_rules.dart` for this file.

Stream patterns, subscriptions, and broadcasting:

- `AvoidStreamToStringRule`
- `AvoidUnassignedStreamSubscriptionsRule`
- `PreferCorrectStreamReturnTypeRule`
- `AvoidNestedStreamsAndFuturesRule`
- `RequireStreamControllerCloseRule`
- `AvoidMultipleStreamListenersRule`
- `RequireStreamErrorHandlingRule`
- `RequireStreamOnDoneRule`
- `PreferStreamDistinctRule`
- `PreferBroadcastStreamRule`

### 5c. NEW `async_widget_rules.dart` (9 rules)

Async patterns specific to Flutter widgets:

- `AvoidDialogContextAfterAsyncRule`
- `CheckMountedAfterAsyncRule`
- `AvoidStreamInBuildRule`
- `AvoidFutureInBuildRule`
- `RequireMountedCheckAfterAwaitRule`
- `AvoidAsyncInBuildRule`
- `PreferAsyncInitStateRule`
- `AvoidPassingAsyncWhenSyncExpectedRule`
- `PreferAsyncCallbackRule`

### 5d. Remaining async rules (15 rules)

Relocate to existing or new files by domain:

| Rule | Target file |
|------|-------------|
| `RequireFutureTimeoutRule` | `future_rules.dart` (new) |
| `RequireFutureWaitErrorHandlingRule` | `future_rules.dart` (new) |
| `RequireCompleterErrorHandlingRule` | `future_rules.dart` (new) |
| `AvoidStreamSubscriptionInFieldRule` | `stream_rules2.dart` (new) |
| `PreferFutureVoidFunctionOverAsyncCallbackRule` | `future_rules.dart` (new) |
| `AvoidFutureThenInAsyncRule` | `future_rules.dart` (new) |
| `RequireWebsocketMessageValidationRule` | `connectivity_rules.dart` |
| `RequireFeatureFlagDefaultRule` | `config_rules.dart` |
| `RequireLocationTimeoutRule` | `platform_rules.dart` |
| `PreferUtcForStorageRule` | `json_datetime_rules.dart` |
| `RequireNetworkStatusCheckRule` | `connectivity_rules.dart` |
| `AvoidSyncOnEveryChangeRule` | `performance_rules.dart` |
| `RequirePendingChangesIndicatorRule` | `ui_ux_rules.dart` |
| `AvoidStreamSyncEventsRule` | `stream_rules2.dart` (new) |
| `AvoidSequentialAwaitsRule` | `performance_rules.dart` |

---

## Summary: New Files Created

| New file | Rules | Source |
|----------|------:|--------|
| `widget_text_rules.dart` | 9 | Phase 1b |
| `widget_gesture_rules.dart` | 12 | Phase 1c + 3f extras |
| `widget_theme_rules.dart` | 10 | Phase 1f |
| `widget_architecture_rules.dart` | 21 | Phase 1g + 3f extras |
| `widget_platform_rules.dart` | 21 | Phase 1h + 3f extras |
| `string_rules.dart` | 7 | Phase 2a |
| `enum_switch_rules.dart` | 10 | Phase 2b |
| `switch_shorthand_rules.dart` | 9 | Phase 2c |
| `parameter_rules.dart` | 11 | Phase 2e |
| `variable_rules.dart` | 19 | Phase 2f |
| `flex_rules.dart` | 10 | Phase 3a + 3f extras |
| `sliver_rules.dart` | 4 | Phase 3c |
| `sizing_rules.dart` | 18 | Phase 3d + 3f extras |
| `container_rules.dart` | 5 | Phase 3e |
| `secure_storage_rules.dart` | 13 | Phase 4a + 4e extras |
| `credential_rules.dart` | 10 | Phase 4b + 4e extras |
| `network_security_rules.dart` | 8 | Phase 4c |
| `input_validation_rules.dart` | 9 | Phase 4d + 4e extras |
| `future_rules.dart` | 17 | Phase 5a + 5d extras |
| `stream_rules2.dart` | 12 | Phase 5b + 5d extras |
| `async_widget_rules.dart` | 9 | Phase 5c |

## Summary: Existing Files Modified (merges)

| Existing file | Added | New total |
|---------------|------:|----------:|
| `image_rules.dart` | +11 | ~30 |
| `forms_rules.dart` | +8 | ~31 |
| `navigation_rules.dart` | +11 | ~45 |
| `scroll_rules.dart` | +16 | ~29 |
| `control_flow_rules.dart` | +15 | ~43 |
| `type_safety_rules.dart` | +11 | ~27 |
| `crypto_rules.dart` | +2 | varies |
| `performance_rules.dart` | +8 | varies |
| `build_method_rules.dart` | +3 | varies |
| `various others` | +1-2 each | varies |

## Execution Order

1. **Phase 1** first - `widget_patterns_rules.dart` is the most tangled
2. **Phase 2** next - `code_quality_rules.dart` has the most rules
3. **Phase 3** after - `widget_layout_rules.dart` depends on new Phase 1 files
4. **Phase 4** then - `security_rules.dart` is more self-contained
5. **Phase 5** last - `async_rules.dart` is smallest and most focused

After each phase:
- Update `all_rules.dart` exports
- Run `/analyze` to verify no broken imports
- Run `/test` to verify no regressions
- Commit the phase

## Risks & Notes

1. **`navigation_rules.dart` at 45 rules** - flag for future split
2. **`control_flow_rules.dart` at 43 rules** - flag for future split
3. **Duplicate rules found** - `AvoidUnnecessaryToListRule` and `PreferTypedDataRule`
   appear in multiple source files; deduplicate during migration
4. **`stream_rules2.dart` naming** - consider renaming existing `scroll_rules.dart`
   to free up the `stream_rules.dart` name
5. **`all_rules.dart` must be updated** after every file move
6. **`tiers.dart` references** - verify tier assignments remain correct after moves
