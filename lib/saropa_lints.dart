// ignore_for_file: depend_on_referenced_packages

/// Custom lint rules for Saropa codebase.
///
/// ## Configuration
///
/// Add to your `analysis_options.yaml`:
///
/// ```yaml
/// custom_lint:
///   saropa_lints:
///     tier: recommended  # essential | recommended | professional | comprehensive | insanity
/// ```
///
/// Available tiers:
/// - `essential`: Critical rules (~45) - prevents crashes, security issues
/// - `recommended`: Essential + common mistakes (~150) - default for most teams
/// - `professional`: Recommended + architecture/testing (~350) - enterprise teams
/// - `comprehensive`: Professional + thorough coverage (~700) - quality obsessed
/// - `insanity`: Everything (~475+) - greenfield projects
///
/// You can also enable/disable individual rules.
///
/// **IMPORTANT:** Rules must use YAML list format (with `-` prefix):
///
/// ```yaml
/// custom_lint:
///   saropa_lints:
///     tier: recommended
///   rules:
///     - avoid_debug_print: false  # disable a rule
///     - no_magic_number: true     # enable a rule not in your tier
/// ```
///
/// Map format (without `-`) is silently ignored by custom_lint!
library;

import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'package:saropa_lints/src/rules/all_rules.dart';
import 'package:saropa_lints/src/tiers.dart';

// Export all rule classes for documentation
export 'package:saropa_lints/src/rules/all_rules.dart';
export 'package:saropa_lints/src/saropa_lint_rule.dart'
    show ImpactTracker, LintImpact, SaropaLintRule, ViolationRecord;
export 'package:saropa_lints/src/tiers.dart';

/// All available Saropa lint rules.
///
/// This getter provides access to all rule instances for tools
/// like the impact report that need to query rule metadata.
List<LintRule> get allSaropaRules => _allRules;

/// Entry point for custom_lint
PluginBase createPlugin() => _SaropaLints();

/// All available rules - instantiated once
const List<LintRule> _allRules = <LintRule>[
  // Core rules
  AlwaysFailRule(),
  AvoidNullAssertionRule(),
  AvoidDebugPrintRule(),
  AvoidUnguardedDebugRule(),
  PreferConstStringListRule(),
  AvoidContextInInitStateDisposeRule(),
  AvoidIsarEnumFieldRule(),
  AvoidAdjacentStringsRule(),
  AvoidContinueRule(),
  AvoidEmptySpreadRule(),
  AvoidOnlyRethrowRule(),
  NoEmptyStringRule(),
  PreferContainsRule(),
  PreferFirstRule(),
  RequireDisposeRule(),
  RequireTimerCancellationRule(),
  NullifyAfterDisposeRule(),
  AvoidMisnamedPaddingRule(),
  AvoidUnsafeSetStateRule(),
  AvoidRedundantElseRule(),
  AvoidDuplicateMapKeysRule(),
  AvoidNestedSwitchesRule(),
  AvoidLocalFunctionsRule(),
  AvoidUnnecessarySuperRule(),
  AvoidNestedFuturesRule(),
  AvoidOneFieldRecordsRule(),
  AvoidNestedTryRule(),
  AvoidMapKeysContainsRule(),
  AvoidEmptySetStateRule(),
  AvoidSingleChildColumnRowRule(),
  AvoidLongParameterListRule(),
  PreferBooleanPrefixesRule(),
  PreferBooleanPrefixesForLocalsRule(),
  PreferBooleanPrefixesForParamsRule(),
  AvoidReturningCascadesRule(),
  AvoidPositionalRecordFieldAccessRule(),
  AvoidDeclaringCallMethodRule(),
  AvoidUnmarkedPublicClassRule(),
  PreferFinalClassRule(),
  PreferInterfaceClassRule(),
  PreferBaseClassRule(),
  AvoidNestedStreamsAndFuturesRule(),
  AvoidIfWithManyBranchesRule(),
  AvoidInvertedBooleanChecksRule(),
  AvoidNegatedConditionsRule(),
  AvoidStreamToStringRule(),
  AvoidStatelessWidgetInitializedFieldsRule(),
  AvoidStateConstructorsRule(),
  AvoidAssignmentsAsConditionsRule(),
  AvoidConditionsWithBooleanLiteralsRule(),
  AvoidSelfAssignmentRule(),
  AvoidSelfCompareRule(),
  NoEmptyBlockRule(),
  PreferLastRule(),
  AvoidDoubleSlashImportsRule(),
  AvoidNestedRecordsRule(),
  PreferCommentingAnalyzerIgnoresRule(),
  AvoidReturningVoidRule(),
  AvoidUnnecessaryConstructorRule(),
  AvoidWeakCryptographicAlgorithmsRule(),
  NoObjectDeclarationRule(),
  PreferReturningConditionRule(),
  PreferSimplerBooleanExpressionsRule(),
  PreferWhenGuardOverIfRule(),
  PreferDedicatedMediaQueryMethodRule(),
  AvoidCascadeAfterIfNullRule(),
  AvoidDuplicateExportsRule(),
  NoEqualThenElseRule(),
  AvoidGlobalStateRule(),
  PreferImmediateReturnRule(),
  PreferIterableOfRule(),
  AvoidExpandedAsSpacerRule(),
  AvoidDuplicateMixinsRule(),
  AvoidDuplicateNamedImportsRule(),
  AvoidThrowInCatchBlockRule(),
  AvoidUnnecessaryConditionalsRule(),
  PreferEnumsByNameRule(),
  AvoidBorderAllRule(),
  PreferConstBorderRadiusRule(),
  AvoidRedundantAsyncRule(),
  AvoidPassingSelfAsArgumentRule(),
  PreferCorrectEdgeInsetsConstructorRule(),
  PreferTextRichRule(),
  AvoidWrappingInPaddingRule(),
  PreferDefineHeroTagRule(),
  AvoidNullableToStringRule(),
  AvoidIncorrectImageOpacityRule(),
  PreferUsingListViewRule(),
  AvoidMissingImageAltRule(),
  AvoidDuplicateTestAssertionsRule(),
  MissingTestAssertionRule(),
  AvoidAsyncCallbackInFakeAsyncRule(),
  PreferSymbolOverKeyRule(),
  UseSetStateSynchronouslyRule(),
  AvoidSubstringRule(),
  AvoidTopLevelMembersInTestsRule(),
  AvoidUnnecessaryTypeAssertionsRule(),
  AvoidUnnecessaryTypeCastsRule(),
  AvoidExplicitPatternFieldNameRule(),
  AlwaysRemoveListenerRule(),
  AvoidGenericsShadowingRule(),
  AvoidMissedCallsRule(),
  AvoidMisusedSetLiteralsRule(),
  AvoidUnrelatedTypeAssertionsRule(),
  AvoidUnusedParametersRule(),
  PreferCorrectTestFileNameRule(),
  AvoidCastingToExtensionTypeRule(),
  AvoidCollectionMethodsWithUnrelatedTypesRule(),
  AvoidIncompleteCopyWithRule(),
  AvoidUnnecessarySetStateRule(),
  AvoidUnnecessaryStatefulWidgetsRule(),
  CheckForEqualsInRenderObjectSettersRule(),
  ConsistentUpdateRenderObjectRule(),
  AvoidSingleFieldDestructuringRule(),
  AvoidUnsafeCollectionMethodsRule(),
  AvoidUnsafeWhereMethodsRule(),
  PreferWhereOrNullRule(),
  PreferNamedBooleanParametersRule(),
  PreferEarlyReturnRule(),
  AvoidFlexibleOutsideFlexRule(),
  ProperSuperCallsRule(),
  AvoidNestedAssignmentsRule(),
  AvoidUnconditionalBreakRule(),
  AvoidUnnecessaryReturnRule(),
  AvoidBitwiseOperatorsWithBooleansRule(),
  AvoidCollapsibleIfRule(),
  AvoidFunctionTypeInRecordsRule(),
  AvoidNestedSwitchExpressionsRule(),
  NoEqualConditionsRule(),
  AvoidUnnecessaryNegationsRule(),
  PreferCorrectIdentifierLengthRule(),
  AvoidUnsafeReduceRule(),
  PreferNamedParametersRule(),
  AvoidRecursiveCallsRule(),
  AvoidRecursiveToStringRule(),
  AvoidShadowingRule(),
  AvoidThrowObjectsWithoutToStringRule(),
  AvoidDuplicateCascadesRule(),
  AvoidEqualExpressionsRule(),
  ExtendEquatableRule(),
  ListAllEquatableFieldsRule(),
  PreferEquatableMixinRule(),
  AvoidCollectionEqualityChecksRule(),
  AvoidDuplicateSwitchCaseConditionsRule(),
  AvoidMixingNamedAndPositionalFieldsRule(),
  AvoidMultiAssignmentRule(),
  NoMagicStringRule(),
  PreferTypeOverVarRule(),
  AvoidMountedInSetStateRule(),
  PreferSliverPrefixRule(),
  AvoidConstantAssertConditionsRule(),
  AvoidConstantSwitchesRule(),
  AvoidUnnecessaryGetterRule(),
  AvoidLateContextRule(),
  AvoidUnnecessaryGestureDetectorRule(),
  PreferWidgetPrivateMembersRule(),
  AvoidBarrelFilesRule(),
  AvoidBottomTypeInPatternsRule(),
  AvoidBottomTypeInRecordsRule(),
  AvoidExtensionsOnRecordsRule(),
  AvoidImmediatelyInvokedFunctionsRule(),
  AvoidLongFilesRule(),
  AvoidLongFunctionsRule(),
  AvoidLongRecordsRule(),
  AvoidComplexArithmeticExpressionsRule(),
  AvoidComplexConditionsRule(),
  AvoidNonAsciiSymbolsRule(),
  AvoidNonEmptyConstructorBodiesRule(),
  AvoidRedundantPositionalFieldNameRule(),
  AvoidReferencingDiscardedVariablesRule(),
  AvoidUnnecessaryBlockRule(),
  AvoidUnnecessaryCallRule(),
  AvoidUnnecessaryContinueRule(),
  AvoidUnnecessaryExtendsRule(),
  AvoidInconsistentDigitSeparatorsRule(),
  AvoidIncorrectUriRule(),
  MaxImportsRule(),
  PreferAdditionSubtractionAssignmentsRule(),
  PreferCorrectErrorNameRule(),
  PreferTrailingCommaRule(),
  FormatCommentRule(),
  NoEqualArgumentsRule(),
  PreferCompoundAssignmentOperatorsRule(),
  PreferCorrectSetterParameterNameRule(),
  PreferDigitSeparatorsRule(),
  PreferExplicitFunctionTypeRule(),
  PreferNullAwareSpreadRule(),
  PreferParenthesesWithIfNullRule(),
  AvoidImplicitlyNullableExtensionTypesRule(),
  AvoidKeywordsInWildcardPatternRule(),
  AvoidNegationsInEqualityChecksRule(),
  MatchGetterSetterFieldNamesRule(),
  PreferWildcardPatternRule(),
  AvoidNullableParametersWithDefaultValuesRule(),
  AvoidUnnecessaryCollectionsRule(),
  AvoidUnnecessaryDigitSeparatorsRule(),
  AvoidUnnecessaryEnumArgumentsRule(),
  PreferDescriptiveTestNameRule(),
  PreferCorrectSwitchLengthRule(),
  PreferCorrectTypeNameRule(),
  PreferReturningConditionalsRule(),
  AvoidExcessiveExpressionsRule(),
  MapKeysOrderingRule(),
  ArgumentsOrderingRule(),
  MatchClassNamePatternRule(),
  NewlineBeforeCaseRule(),
  EnumConstantsOrderingRule(),
  ParametersOrderingConventionRule(),
  PreferCorrectHandlerNameRule(),
  PreferUniqueTestNamesRule(),
  UnnecessaryTrailingCommaRule(),
  AvoidRedundantPragmaInlineRule(),
  AvoidUnknownPragmaRule(),
  NewlineBeforeMethodRule(),
  PreferExplicitParameterNamesRule(),
  PreferPrefixedGlobalConstantsRule(),
  PreferPrivateExtensionTypeFieldRule(),
  PreferReturningShorthandsRule(),
  RecordFieldsOrderingRule(),
  PreferPatternDestructuringRule(),
  MatchLibFolderStructureRule(),
  MoveRecordsToTypedefsRule(),
  NewlineBeforeConstructorRule(),
  PatternFieldsOrderingRule(),
  PreferBothInliningAnnotationsRule(),
  PreferCommentingFutureDelayedRule(),
  PreferSimplerPatternsNullCheckRule(),
  PreferSortedParametersRule(),
  PreferVisibleForTestingOnMembersRule(),
  MatchPositionalFieldNamesOnAssignmentRule(),
  MissingUseResultAnnotationRule(),
  PreferAssigningAwaitExpressionsRule(),
  PreferCorrectFutureReturnTypeRule(),
  PreferCorrectStreamReturnTypeRule(),
  PreferExtractingFunctionCallbacksRule(),
  PreferNamedImportsRule(),
  PreferNullAwareElementsRule(),
  PreferTestStructureRule(),
  TagNameRule(),
  AvoidNestedShorthandsRule(),
  AvoidGetterPrefixRule(),
  AvoidEmptyTestGroupsRule(),
  AvoidEnumValuesByIndexRule(),
  AvoidUnnecessaryLengthCheckRule(),
  AvoidUnnecessaryCompareToRule(),
  AvoidFutureIgnoreRule(),
  AvoidFutureToStringRule(),
  PreferCorrectCallbackFieldNameRule(),
  AvoidNullableInterpolationRule(),
  AvoidNonFinalExceptionClassFieldsRule(),
  AvoidUnnecessaryEnumPrefixRule(),
  AvoidUnassignedStreamSubscriptionsRule(),
  PreferExpectLaterRule(),
  PreferPublicExceptionClassesRule(),
  PreferSpecifyingFutureValueTypeRule(),
  AvoidUnremovableCallbacksInListenersRule(),
  PreferDeclaringConstConstructorRule(),
  AvoidUnnecessaryIfRule(),

  // Noisy rules - disabled by default but available
  AvoidCommentedOutCodeRule(),
  AvoidDynamicRule(),
  AvoidLateKeywordRule(),
  AvoidNestedConditionalExpressionsRule(),
  AvoidPassingAsyncWhenSyncExpectedRule(),
  BinaryExpressionOperandOrderRule(),
  DoubleLiteralFormatRule(),
  MemberOrderingRule(),
  NewlineBeforeReturnRule(),
  NoMagicNumberRule(),
  PreferAsyncAwaitRule(),
  PreferConditionalExpressionsRule(),
  PreferMatchFileNameRule(),
  PreferMovingToVariableRule(),
  PreferStaticClassRule(),
  AvoidReturningWidgetsRule(),
  AvoidShrinkWrapInListsRule(),
  PreferExtractingCallbacksRule(),
  PreferSingleWidgetPerFileRule(),

  // Collection rules
  PreferAddAllRule(),
  AvoidDuplicateCollectionElementsRule(),
  PreferReturnAwaitRule(),
  PreferSetForLookupRule(),

  // Code quality rules
  AvoidUnnecessaryLocalVariableRule(),
  AvoidUnnecessaryReassignmentRule(),
  PreferStaticMethodRule(),
  PreferAbstractFinalStaticClassRule(),
  AvoidHardcodedColorsRule(),

  // Flutter widget rules
  AvoidDeeplyNestedWidgetsRule(),
  RequireAnimationDisposalRule(),
  AvoidUncontrolledTextFieldRule(),
  AvoidHardcodedAssetPathsRule(),
  AvoidPrintInProductionRule(),
  AvoidCatchingGenericExceptionRule(),
  AvoidServiceLocatorOveruseRule(),
  PreferUtcDateTimesRule(),
  AvoidRegexInLoopRule(),
  PreferGetterOverMethodRule(),
  PreferNamedExtensionsRule(),
  PreferTypedefForCallbacksRule(),
  PreferEnhancedEnumsRule(),
  PreferWildcardForUnusedParamRule(),
  AvoidUnusedCallbackParametersRule(),
  PreferConstWidgetsInListsRule(),
  AvoidScaffoldMessengerAfterAwaitRule(),
  AvoidBuildContextInProvidersRule(),
  PreferSemanticWidgetNamesRule(),
  AvoidTextScaleFactorRule(),
  PreferWidgetStateMixinRule(),
  AvoidImageWithoutCacheRule(),
  PreferSplitWidgetConstRule(),
  AvoidNavigatorPushWithoutRouteNameRule(),
  AvoidDuplicateWidgetKeysRule(),
  PreferSafeAreaConsumerRule(),
  AvoidUnrestrictedTextFieldLengthRule(),
  PreferScaffoldMessengerMaybeOfRule(),
  AvoidFormWithoutKeyRule(),

  // Async rules
  AvoidUnusedGenericsRule(),
  PreferTrailingUnderscoreForUnusedRule(),
  AvoidUnnecessaryFuturesRule(),
  AvoidThrowInFinallyRule(),
  AvoidUnnecessaryNullableReturnTypeRule(),
  PreferAsyncCallbackRule(),
  PreferFutureVoidFunctionOverAsyncCallbackRule(),

  // Performance rules
  AvoidListViewWithoutItemExtentRule(),
  AvoidMediaQueryInBuildRule(),
  PreferSliverListDelegateRule(),
  AvoidLayoutBuilderMisuseRule(),
  AvoidRepaintBoundaryMisuseRule(),
  AvoidSingleChildScrollViewWithColumnRule(),
  PreferCachedNetworkImageRule(),
  AvoidGestureDetectorInScrollViewRule(),
  AvoidStatefulWidgetInListRule(),
  PreferOpacityWidgetRule(),

  // Additional code quality rules
  AvoidAlwaysNullParametersRule(),
  AvoidAssigningToStaticFieldRule(),
  AvoidAsyncCallInSyncFunctionRule(),
  AvoidComplexLoopConditionsRule(),
  AvoidConstantConditionsRule(),
  AvoidContradictoryExpressionsRule(),
  AvoidIdenticalExceptionHandlingBlocksRule(),
  AvoidLateFinalReassignmentRule(),
  AvoidMissingCompleterStackTraceRule(),
  AvoidMissingEnumConstantInMapRule(),
  AvoidMutatingParametersRule(),
  AvoidSimilarNamesRule(),
  AvoidUnnecessaryNullableParametersRule(),
  FunctionAlwaysReturnsNullRule(),
  AvoidAccessingCollectionsByConstantIndexRule(),
  AvoidDefaultToStringRule(),
  AvoidDuplicateConstantValuesRule(),
  AvoidDuplicateInitializersRule(),
  AvoidUnnecessaryOverridesRule(),
  AvoidUnnecessaryStatementsRule(),
  AvoidUnusedAssignmentRule(),
  AvoidUnusedInstancesRule(),
  AvoidUnusedAfterNullCheckRule(),
  AvoidWildcardCasesWithEnumsRule(),
  FunctionAlwaysReturnsSameValueRule(),
  NoEqualNestedConditionsRule(),
  NoEqualSwitchCaseRule(),
  PreferAnyOrEveryRule(),
  PreferForInRule(),
  AvoidDuplicatePatternsRule(),
  AvoidNestedExtensionTypesRule(),
  AvoidSlowCollectionMethodsRule(),
  AvoidUnassignedFieldsRule(),
  AvoidUnassignedLateFieldsRule(),
  AvoidUnnecessaryLateFieldsRule(),
  AvoidUnnecessaryNullableFieldsRule(),
  AvoidUnnecessaryPatternsRule(),
  AvoidWildcardCasesWithSealedClassesRule(),
  NoEqualSwitchExpressionCasesRule(),
  PreferBytesBuilderRule(),
  PreferPushingConditionalExpressionsRule(),
  PreferShorthandsWithConstructorsRule(),
  PreferShorthandsWithEnumsRule(),
  PreferShorthandsWithStaticFieldsRule(),

  // Medium complexity rules
  PassCorrectAcceptedTypeRule(),
  PassOptionalArgumentRule(),
  PreferSingleDeclarationPerFileRule(),
  PreferSwitchExpressionRule(),
  PreferSwitchWithEnumsRule(),
  PreferSwitchWithSealedClassesRule(),
  PreferTestMatchersRule(),
  PreferUnwrappingFutureOrRule(),

  // Hard complexity rules
  AvoidInferrableTypeArgumentsRule(),
  AvoidPassingDefaultValuesRule(),
  AvoidShadowedExtensionMethodsRule(),
  AvoidUnnecessaryLocalLateRule(),
  MatchBaseClassDefaultValueRule(),
  MoveVariableCloserToUsageRule(),
  MoveVariableOutsideIterationRule(),
  PreferOverridingParentEqualityRule(),
  PreferSpecificCasesFirstRule(),
  UseExistingDestructuringRule(),
  UseExistingVariableRule(),

  // Flutter-specific rules
  AvoidInheritedWidgetInInitStateRule(),
  AvoidRecursiveWidgetCallsRule(),
  AvoidUndisposedInstancesRule(),
  AvoidUnnecessaryOverridesInStateRule(),
  DisposeFieldsRule(),
  PassExistingFutureToFutureBuilderRule(),
  PassExistingStreamToStreamBuilderRule(),
  AvoidEmptyTextWidgetsRule(),
  AvoidFontWeightAsNumberRule(),
  PreferSizedBoxForWhitespaceRule(),
  PreferSizedBoxSquareRule(),
  PreferCenterOverAlignRule(),
  PreferAlignOverContainerRule(),
  PreferPaddingOverContainerRule(),
  PreferConstrainedBoxOverContainerRule(),
  PreferTransformOverContainerRule(),
  PreferActionButtonTooltipRule(),
  PreferVoidCallbackRule(),
  AvoidNestedScaffoldsRule(),
  AvoidMultipleMaterialAppsRule(),
  AvoidRawKeyboardListenerRule(),
  AvoidImageRepeatRule(),
  AvoidIconSizeOverrideRule(),
  PreferInkwellOverGestureRule(),
  AvoidFittedBoxForTextRule(),
  PreferListViewBuilderRule(),
  AvoidOpacityAnimationRule(),
  AvoidSizedBoxExpandRule(),
  PreferSelectableTextRule(),
  PreferSpacingOverSizedBoxRule(),
  AvoidMaterial2FallbackRule(),
  PreferOverlayPortalRule(),
  PreferCarouselViewRule(),
  PreferSearchAnchorRule(),
  PreferTapRegionForDismissRule(),

  // Accessibility rules (NEW)
  AvoidIconButtonsWithoutTooltipRule(),
  AvoidSmallTouchTargetsRule(),
  RequireExcludeSemanticsJustificationRule(),
  AvoidColorOnlyIndicatorsRule(),
  AvoidGestureOnlyInteractionsRule(),
  RequireSemanticsLabelRule(),
  AvoidMergedSemanticsHidingInfoRule(),
  RequireLiveRegionRule(),
  RequireHeadingSemanticsRule(),
  AvoidImageButtonsWithoutTooltipRule(),

  // Security rules (NEW)
  AvoidLoggingSensitiveDataRule(),
  RequireSecureStorageRule(),
  AvoidHardcodedCredentialsRule(),
  RequireInputSanitizationRule(),
  AvoidWebViewJavaScriptEnabledRule(),
  RequireBiometricFallbackRule(),
  AvoidEvalLikePatternsRule(),
  RequireCertificatePinningRule(),
  AvoidTokenInUrlRule(),
  AvoidGenericKeyInUrlRule(),
  AvoidClipboardSensitiveRule(),
  AvoidStoringPasswordsRule(),

  // Performance rules (NEW)
  RequireKeysInAnimatedListsRule(),
  AvoidExpensiveBuildRule(),
  PreferConstChildWidgetsRule(),
  AvoidSynchronousFileIoRule(),
  PreferComputeForHeavyWorkRule(),
  AvoidObjectCreationInHotLoopsRule(),
  PreferCachedGetterRule(),
  AvoidExcessiveWidgetDepthRule(),
  RequireItemExtentForLargeListsRule(),
  RequireImageCacheDimensionsRule(),
  PreferImagePrecacheRule(),
  AvoidControllerInBuildRule(),
  AvoidSetStateInBuildRule(),
  AvoidStringConcatenationLoopRule(),
  AvoidLargeListCopyRule(),

  // State management rules (NEW)
  RequireNotifyListenersRule(),
  RequireStreamControllerDisposeRule(),
  RequireValueNotifierDisposeRule(),
  RequireMountedCheckRule(),
  AvoidWatchInCallbacksRule(),
  AvoidBlocEventInConstructorRule(),
  RequireUpdateShouldNotifyRule(),
  AvoidGlobalRiverpodProvidersRule(),
  AvoidStatefulWithoutStateRule(),
  AvoidGlobalKeyInBuildRule(),

  // Error handling rules (NEW)
  AvoidSwallowingExceptionsRule(),
  AvoidLosingStackTraceRule(),
  // RequireFutureErrorHandlingRule merged into AvoidUncaughtFutureErrorsRule
  AvoidGenericExceptionsRule(),
  RequireErrorContextRule(),
  PreferResultPatternRule(),
  RequireAsyncErrorDocumentationRule(),
  RequireErrorBoundaryRule(),

  // Architecture rules (NEW)
  AvoidDirectDataAccessInUiRule(),
  AvoidBusinessLogicInUiRule(),
  AvoidCircularDependenciesRule(),
  AvoidGodClassRule(),
  AvoidUiInDomainLayerRule(),
  AvoidCrossFeatureDependenciesRule(),
  AvoidSingletonPatternRule(),

  // Documentation rules (NEW)
  RequirePublicApiDocumentationRule(),
  AvoidMisleadingDocumentationRule(),
  RequireDeprecationMessageRule(),
  RequireComplexLogicCommentsRule(),
  RequireParameterDocumentationRule(),
  RequireReturnDocumentationRule(),
  RequireExceptionDocumentationRule(),
  RequireExampleInDocumentationRule(),

  // NOTE: always_fail is intentionally NOT here - it's a test hook only best practices rules (NEW)
  RequireTestAssertionsRule(),
  AvoidVagueTestDescriptionsRule(),
  AvoidRealNetworkCallsInTestsRule(),
  AvoidHardcodedTestDelaysRule(),
  RequireTestSetupTeardownRule(),
  RequirePumpAfterInteractionRule(),
  AvoidProductionConfigInTestsRule(),

  // Internationalization rules (NEW)
  AvoidHardcodedStringsInUiRule(),
  RequireLocaleAwareFormattingRule(),
  RequireDirectionalWidgetsRule(),
  RequirePluralHandlingRule(),
  AvoidHardcodedLocaleRule(),
  AvoidStringConcatenationInUiRule(),
  AvoidTextInImagesRule(),
  AvoidHardcodedAppNameRule(),

  // API & Network rules (NEW)
  RequireHttpStatusCheckRule(),
  // RequireApiTimeoutRule merged into RequireRequestTimeoutRule
  AvoidHardcodedApiUrlsRule(),
  RequireRetryLogicRule(),
  RequireTypedApiResponseRule(),
  RequireConnectivityCheckRule(),
  RequireApiErrorMappingRule(),

  // Dependency Injection rules (NEW)
  AvoidServiceLocatorInWidgetsRule(),
  AvoidTooManyDependenciesRule(),
  AvoidInternalDependencyCreationRule(),
  PreferAbstractDependenciesRule(),
  AvoidSingletonForScopedDependenciesRule(),
  AvoidCircularDiDependenciesRule(),
  PreferNullObjectPatternRule(),
  RequireTypedDiRegistrationRule(),
  AvoidFunctionsInRegisterSingletonRule(),

  // Memory Management rules (NEW)
  AvoidLargeObjectsInStateRule(),
  RequireImageDisposalRule(),
  AvoidCapturingThisInCallbacksRule(),
  RequireCacheEvictionPolicyRule(),
  PreferWeakReferencesForCacheRule(),
  AvoidExpandoCircularReferencesRule(),
  AvoidLargeIsolateCommunicationRule(),

  // Type Safety rules (NEW)
  AvoidUnsafeCastRule(),
  PreferConstrainedGenericsRule(),
  RequireCovariantDocumentationRule(),
  RequireSafeJsonParsingRule(),
  RequireNullSafeExtensionsRule(),
  PreferSpecificNumericTypesRule(),
  RequireFutureOrDocumentationRule(),

  // Resource Management rules (NEW)
  RequireFileCloseInFinallyRule(),
  RequireHiveDatabaseCloseRule(),
  RequireHttpClientCloseRule(),
  RequireNativeResourceCleanupRule(),
  RequireWebSocketCloseRule(),
  RequirePlatformChannelCleanupRule(),
  RequireIsolateKillRule(),

  // New formatting rules
  AvoidDigitSeparatorsRule(),
  FormatCommentFormattingRule(),
  MemberOrderingFormattingRule(),
  ParametersOrderingConventionRule(),

  // New widget rules
  RequireTextOverflowHandlingRule(),
  RequireImageErrorBuilderRule(),
  RequireImageDimensionsRule(),
  RequirePlaceholderForNetworkRule(),
  RequireScrollControllerDisposeRule(),
  RequireFocusNodeDisposeRule(),
  PreferTextThemeRule(),
  AvoidNestedScrollablesRule(),

  // New widget rules from roadmap (batch 1)
  AvoidHardcodedLayoutValuesRule(),
  PreferIgnorePointerRule(),
  AvoidGestureWithoutBehaviorRule(),
  AvoidDoubleTapSubmitRule(),
  PreferCursorForButtonsRule(),
  RequireHoverStatesRule(),
  RequireButtonLoadingStateRule(),
  AvoidHardcodedTextStylesRule(),
  PreferPageStorageKeyRule(),
  RequireRefreshIndicatorRule(),

  // New widget rules from roadmap (batch 2 - Very Easy)
  RequireScrollPhysicsRule(),
  PreferSliverListRule(),
  PreferKeepAliveRule(),
  RequireDefaultTextStyleRule(),
  PreferWrapOverOverflowRule(),
  PreferAssetImageForLocalRule(),
  PreferFitCoverForBackgroundRule(),
  RequireDisabledStateRule(),
  RequireDragFeedbackRule(),

  // New widget rules from roadmap (batch 2 - Easy)
  AvoidGestureConflictRule(),
  AvoidLargeImagesInMemoryRule(),
  AvoidLayoutBuilderInScrollableRule(),
  PreferIntrinsicDimensionsRule(),
  PreferActionsAndShortcutsRule(),
  RequireLongPressCallbackRule(),
  AvoidFindChildInBuildRule(),
  AvoidUnboundedConstraintsRule(),

  // New test rules from roadmap
  AvoidTestSleepRule(),
  AvoidFindByTextRule(),
  RequireTestKeysRule(),

  // New test rule
  PreferPumpAndSettleRule(),

  // New state management rules
  RequireBlocCloseRule(),
  PreferConsumerWidgetRule(),
  RequireAutoDisposeRule(),

  // New security rule
  AvoidDynamicSqlRule(),

  // Stylistic / Opinionated rules (not in any tier by default)
  PreferRelativeImportsRule(),
  PreferOneWidgetPerFileRule(),
  PreferArrowFunctionsRule(),
  PreferAllNamedParametersRule(),
  PreferTrailingCommaAlwaysRule(),
  PreferPrivateUnderscorePrefixRule(),
  PreferWidgetMethodsOverClassesRule(),
  PreferExplicitTypesRule(),
  PreferClassOverRecordReturnRule(),
  PreferInlineCallbacksRule(),
  PreferSingleQuotesRule(),
  PreferTodoFormatRule(),
  PreferFixmeFormatRule(),
  PreferSentenceCaseCommentsRule(),
  PreferPeriodAfterDocRule(),
  PreferScreamingCaseConstantsRule(),
  PreferDescriptiveBoolNamesRule(),
  PreferSnakeCaseFilesRule(),
  AvoidSmallTextRule(),
  PreferDocCommentsOverRegularRule(),
  PreferStraightApostropheRule(),
  PreferCurlyApostropheRule(),

  // Testing best practices rules (batch 3)
  RequireArrangeActAssertRule(),
  PreferMockNavigatorRule(),
  AvoidRealTimerInWidgetTestRule(),
  RequireMockVerificationRule(),
  PreferMatcherOverEqualsRule(),
  PreferTestWrapperRule(),
  RequireScreenSizeTestsRule(),
  AvoidStatefulTestSetupRule(),
  PreferMockHttpRule(),
  RequireGoldenTestRule(),

  // Widget rules (batch 3)
  PreferFractionalSizingRule(),
  AvoidUnconstrainedBoxMisuseRule(),
  RequireErrorWidgetRule(),
  PreferSliverAppBarRule(),
  AvoidOpacityMisuseRule(),
  PreferClipBehaviorRule(),
  RequireScrollControllerRule(),
  PreferPositionedDirectionalRule(),
  AvoidStackOverflowRule(),
  RequireFormValidationRule(),

  // High-impact rules (batch 4)
  AvoidShrinkWrapInScrollRule(),
  AvoidDeepWidgetNestingRule(),
  PreferSafeAreaAwareRule(),
  AvoidRefInBuildBodyRule(),
  RequireImmutableBlocStateRule(),
  RequireRequestTimeoutRule(),
  AvoidFlakyTestsRule(),

  // New accessibility rules
  AvoidTextScaleFactorIgnoreRule(),
  RequireImageSemanticsRule(),
  AvoidHiddenInteractiveRule(),

  // New animation rules
  RequireVsyncMixinRule(),
  AvoidAnimationInBuildRule(),
  RequireAnimationControllerDisposeRule(),
  RequireHeroTagUniquenessRule(),
  AvoidLayoutPassesRule(),

  // New forms rules
  PreferAutovalidateOnInteractionRule(),
  RequireKeyboardTypeRule(),
  RequireTextOverflowInRowRule(),
  RequireSecureKeyboardRule(),

  // New navigation rules
  RequireUnknownRouteHandlerRule(),
  AvoidContextAfterNavigationRule(),

  // New security/performance rules
  PreferSecureRandomRule(),
  PreferTypedDataRule(),
  AvoidUnnecessaryToListRule(),

  // New Firebase/storage rules
  AvoidFirestoreUnboundedQueryRule(),
  AvoidDatabaseInBuildRule(),
  RequirePrefsKeyConstantsRule(),
  AvoidSecureStorageOnWebRule(),
  IncorrectFirebaseEventNameRule(),
  IncorrectFirebaseParameterNameRule(),

  // New state management rules
  AvoidProviderOfInBuildRule(),
  AvoidGetFindInBuildRule(),
  AvoidProviderRecreateRule(),

  AvoidHardcodedDurationRule(),
  RequireAnimationCurveRule(),
  AvoidFixedDimensionsRule(),
  AvoidPrefsForLargeDataRule(),
  RequireOfflineIndicatorRule(),

  PreferCoarseLocationRule(),
  RequireCameraDisposeRule(),
  RequireImageCompressionRule(),
  RequireThemeColorFromSchemeRule(),
  PreferColorSchemeFromSeedRule(),

  PreferRichTextForComplexRule(),
  RequireErrorMessageContextRule(),
  PreferImplicitAnimationsRule(),
  RequireStaggeredAnimationDelaysRule(),
  PreferCubitForSimpleRule(),

  RequireBlocObserverRule(),
  RequireRouteTransitionConsistencyRule(),
  RequireTestGroupsRule(),

  AvoidRefInDisposeRule(),
  RequireProviderScopeRule(),
  PreferSelectForPartialRule(),
  AvoidProviderInWidgetRule(),
  PreferFamilyForParamsRule(),

  // Riverpod rules (from roadmap)
  AvoidRefReadInsideBuildRule(),
  AvoidRefWatchOutsideBuildRule(),
  AvoidRefInsideStateDisposeRule(),
  UseRefReadSynchronouslyRule(),
  UseRefAndStateSynchronouslyRule(),
  AvoidAssigningNotifiersRule(),
  AvoidNotifierConstructorsRule(),
  PreferImmutableProviderArgumentsRule(),

  AvoidScrollListenerInBuildRule(),
  PreferValueListenableBuilderRule(),
  AvoidGlobalKeyMisuseRule(),
  RequireRepaintBoundaryRule(),
  AvoidTextSpanInBuildRule(),

  AvoidTestCouplingRule(),
  RequireTestIsolationRule(),
  AvoidRealDependenciesInTestsRule(),
  RequireScrollTestsRule(),
  RequireTextInputTestsRule(),

  AvoidNavigatorPushUnnamedRule(),
  RequireRouteGuardsRule(),
  AvoidCircularRedirectsRule(),
  AvoidPopWithoutResultRule(),
  PreferShellRouteForPersistentUiRule(),

  RequireAuthCheckRule(),
  RequireTokenRefreshRule(),
  AvoidJwtDecodeClientRule(),
  RequireLogoutCleanupRule(),
  AvoidAuthInQueryParamsRule(),

  AvoidBlocEventMutationRule(),
  PreferMultiBlocProviderRule(),
  AvoidInstantiatingInBlocValueProviderRule(),
  AvoidExistingInstancesInBlocProviderRule(),
  PreferCorrectBlocProviderRule(),
  PreferMultiProviderRule(),
  AvoidInstantiatingInValueProviderRule(),
  DisposeProvidersRule(),
  ProperGetxSuperCallsRule(),
  AlwaysRemoveGetxListenerRule(),
  AvoidHooksOutsideBuildRule(),
  AvoidConditionalHooksRule(),
  AvoidUnnecessaryHookWidgetsRule(),
  PreferCopyWithForStateRule(),
  AvoidBlocListenInBuildRule(),
  RequireInitialStateRule(),
  RequireErrorStateRule(),
  AvoidBlocInBlocRule(),
  PreferSealedEventsRule(),
  CheckIsNotClosedAfterAsyncGapRule(),
  AvoidDuplicateBlocEventHandlersRule(),
  PreferImmutableBlocEventsRule(),
  PreferImmutableBlocStateRule(),
  PreferSealedBlocEventsRule(),
  PreferSealedBlocStateRule(),

  PreferConstWidgetsRule(),
  AvoidExpensiveComputationInBuildRule(),
  AvoidWidgetCreationInLoopRule(),
  RequireBuildContextScopeRule(),
  AvoidCallingOfInBuildRule(),
  RequireImageCacheManagementRule(),
  AvoidMemoryIntensiveOperationsRule(),
  AvoidClosureMemoryLeakRule(),
  PreferStaticConstWidgetsRule(),
  RequireDisposePatternRule(),

  RequireFormKeyRule(),
  AvoidValidationInBuildRule(),
  RequireSubmitButtonStateRule(),
  AvoidFormWithoutUnfocusRule(),
  RequireFormRestorationRule(),
  AvoidClearingFormOnErrorRule(),
  RequireFormFieldControllerRule(),
  AvoidFormInAlertDialogRule(),
  RequireFormAutoValidateModeRule(),
  RequireAutofillHintsRule(),
  PreferOnFieldSubmittedRule(),

  PreferSystemThemeDefaultRule(),
  AvoidAbsorbPointerMisuseRule(),
  AvoidBrightnessCheckForThemeRule(),
  RequireSafeAreaHandlingRule(),
  PreferScalableTextRule(),
  PreferSingleAssertionRule(),
  AvoidFindAllRule(),
  RequireIntegrationTestSetupRule(),
  RequireFirebaseInitBeforeUseRule(),

  // Security rules
  AvoidAuthStateInPrefsRule(),
  PreferEncryptedPrefsRule(),
  // Accessibility rules
  RequireButtonSemanticsRule(),
  PreferExplicitSemanticsRule(),
  AvoidHoverOnlyRule(),
  // State management rules
  PreferRefWatchOverReadRule(),
  AvoidChangeNotifierInWidgetRule(),
  RequireProviderDisposeRule(),
  // Testing rules
  AvoidHardcodedDelaysRule(),
  // Resource management rules
  AvoidImagePickerWithoutSourceRule(),
  // Platform-specific rules
  PreferCupertinoForIosFeelRule(),
  PreferUrlStrategyForWebRule(),
  RequireWindowSizeConstraintsRule(),
  PreferKeyboardShortcutsRule(),
  // Notification rules
  RequireNotificationChannelAndroidRule(),
  AvoidNotificationPayloadSensitiveRule(),

  // Widget rules
  AvoidNullableWidgetMethodsRule(),
  // Code quality rules
  AvoidDuplicateStringLiteralsRule(),
  AvoidDuplicateStringLiteralsPairRule(),
  // State management rules
  AvoidSetStateInLargeStateClassRule(),

  // Widget rules
  RequireOverflowBoxRationaleRule(),
  AvoidUnconstrainedImagesRule(),
  // Accessibility rules
  RequireErrorIdentificationRule(),
  RequireMinimumContrastRule(),
  // Testing rules
  RequireErrorCaseTestsRule(),
  // Security rules
  RequireDeepLinkValidationRule(),
  // Network performance rules
  PreferStreamingResponseRule(),

  // Riverpod rules
  AvoidCircularProviderDepsRule(),
  RequireErrorHandlingInAsyncRule(),
  PreferNotifierOverStateRule(),
  // GetX rules
  RequireGetxControllerDisposeRule(),
  AvoidObsOutsideControllerRule(),
  // Bloc rules
  RequireBlocTransformerRule(),
  AvoidLongEventHandlersRule(),
  // Performance rules
  RequireListPreallocateRule(),
  PreferBuilderForConditionalRule(),
  RequireWidgetKeyStrategyRule(),

  // Network performance rules (batch 5)
  PreferHttpConnectionReuseRule(),
  AvoidRedundantRequestsRule(),
  RequireResponseCachingRule(),
  PreferPaginationRule(),
  AvoidOverFetchingRule(),
  RequireCancelTokenRule(),

  // State management rules (batch 5)
  RequireRiverpodLintRule(),
  RequireMultiProviderRule(),
  AvoidNestedProvidersRule(),

  // Testing rules (batch 5)
  PreferFakeOverMockRule(),
  RequireEdgeCaseTestsRule(),
  PreferTestDataBuilderRule(),
  AvoidTestImplementationDetailsRule(),

  // Security rules (batch 5)
  RequireDataEncryptionRule(),
  PreferDataMaskingRule(),
  AvoidScreenshotSensitiveRule(),
  RequireSecurePasswordFieldRule(),
  AvoidPathTraversalRule(),
  PreferHtmlEscapeRule(),

  // Database rules (batch 5)
  RequireDatabaseMigrationRule(),
  RequireDatabaseIndexRule(),
  PreferTransactionForBatchRule(),
  RequireHiveDatabaseCloseRule(),
  RequireTypeAdapterRegistrationRule(),
  PreferLazyBoxForLargeRule(),

  // Disposal rules (NEW)
  RequireMediaPlayerDisposeRule(),
  RequireTabControllerDisposeRule(),
  RequireTextEditingControllerDisposeRule(),
  RequirePageControllerDisposeRule(),

  // Build method anti-pattern rules (NEW)
  AvoidGradientInBuildRule(),
  AvoidDialogInBuildRule(),
  AvoidSnackbarInBuildRule(),
  AvoidAnalyticsInBuildRule(),
  AvoidJsonEncodeInBuildRule(),
  AvoidGetItInBuildRule(),
  AvoidCanvasInBuildRule(),
  AvoidHardcodedFeatureFlagsRule(),

  // Scroll and list rules (NEW)
  AvoidShrinkWrapInScrollViewRule(),
  AvoidNestedScrollablesConflictRule(),
  AvoidListViewChildrenForLargeListsRule(),
  AvoidExcessiveBottomNavItemsRule(),
  RequireTabControllerLengthSyncRule(),
  AvoidRefreshWithoutAwaitRule(),
  AvoidMultipleAutofocusRule(),
  AvoidShrinkWrapExpensiveRule(),
  PreferItemExtentRule(),
  PreferPrototypeItemRule(),
  RequireKeyForReorderableRule(),
  RequireAddAutomaticKeepAlivesOffRule(),

  // Cryptography rules (NEW)
  AvoidHardcodedEncryptionKeysRule(),
  PreferSecureRandomForCryptoRule(),
  AvoidDeprecatedCryptoAlgorithmsRule(),
  RequireUniqueIvPerEncryptionRule(),

  // JSON and DateTime rules (NEW)
  RequireJsonDecodeTryCatchRule(),
  AvoidDateTimeParseUnvalidatedRule(),
  PreferTryParseForDynamicDataRule(),
  AvoidDoubleForMoneyRule(),
  AvoidSensitiveDataInLogsRule(),
  RequireGetItResetInTestsRule(),
  RequireWebSocketErrorHandlingRule(),
  AvoidAutoplayAudioRule(),

  // Accessibility rules (Plan Group C)
  RequireAvatarAltTextRule(),
  RequireBadgeSemanticsRule(),
  RequireBadgeCountLimitRule(),

  // Image & Media rules (Plan Group A)
  AvoidImageRebuildOnScrollRule(),
  RequireAvatarFallbackRule(),
  PreferVideoLoadingPlaceholderRule(),

  // Dialog & Snackbar rules (Plan Group D)
  RequireSnackbarDurationRule(),
  RequireDialogBarrierDismissibleRule(),
  RequireDialogResultHandlingRule(),
  AvoidSnackbarQueueBuildupRule(),

  // Form & Input rules (Plan Group E)
  RequireKeyboardActionTypeRule(),
  RequireKeyboardDismissOnScrollRule(),

  // Duration & DateTime rules (Plan Group F)
  PreferDurationConstantsRule(),
  AvoidDatetimeNowInTestsRule(),

  // UI/UX Pattern rules (Plan Groups G, J, K)
  RequireResponsiveBreakpointsRule(),
  PreferCachedPaintObjectsRule(),
  RequireCustomPainterShouldRepaintRule(),
  RequireCurrencyFormattingLocaleRule(),
  RequireNumberFormattingLocaleRule(),
  RequireGraphqlOperationNamesRule(),
  AvoidBadgeWithoutMeaningRule(),
  PreferLoggerOverPrintRule(),
  PreferItemExtentWhenKnownRule(),
  RequireTabStatePreservationRule(),

  // Bluetooth & Hardware rules (Plan Group H)
  AvoidBluetoothScanWithoutTimeoutRule(),
  RequireBluetoothStateCheckRule(),
  RequireBleDisconnectHandlingRule(),
  RequireAudioFocusHandlingRule(),
  RequireQrPermissionCheckRule(),
  PreferBleMtuNegotiationRule(),

  // QR Scanner rules (Plan Group I)
  RequireQrScanFeedbackRule(),
  AvoidQrScannerAlwaysActiveRule(),
  RequireQrContentValidationRule(),

  // File & Error Handling rules (Plan Group G)
  RequireFileExistsCheckRule(),
  RequirePdfErrorHandlingRule(),
  RequireGraphqlErrorHandlingRule(),
  AvoidLoadingFullPdfInMemoryRule(),

  // GraphQL rules
  AvoidGraphqlStringQueriesRule(),

  // Image rules (Plan Group A)
  PreferImageSizeConstraintsRule(),

  // Lifecycle rules (Plan Group B)
  RequireLifecycleObserverRule(),

  // Collection & Loop rules (Phase 2)
  PreferCorrectForLoopIncrementRule(),
  AvoidUnreachableForLoopRule(),

  // Widget Optimization rules (Phase 2)
  PreferSingleSetStateRule(),
  PreferComputeOverIsolateRunRule(),
  PreferForLoopInChildrenRule(),
  PreferContainerRule(),

  // Flame Engine rules (Phase 2)
  AvoidCreatingVectorInUpdateRule(),
  AvoidRedundantAsyncOnLoadRule(),

  // Bloc Naming rules (Phase 2)
  PreferBlocEventSuffixRule(),
  PreferBlocStateSuffixRule(),

  // Code Quality rules (Phase 2)
  PreferTypedefsForCallbacksRule(),
  PreferRedirectingSuperclassConstructorRule(),
  AvoidEmptyBuildWhenRule(),
  PreferUsePrefixRule(),

  // Provider Advanced rules (Phase 2)
  PreferImmutableSelectorValueRule(),
  PreferProviderExtensionsRule(),

  // Riverpod Widget rules (Phase 2)
  AvoidUnnecessaryConsumerWidgetsRule(),
  AvoidNullableAsyncValuePatternRule(),

  // GetX Build rules (Phase 2)
  AvoidGetxRxInsideBuildRule(),
  AvoidMutableRxVariablesRule(),

  // Remaining ROADMAP_NEXT rules
  DisposeProvidedInstancesRule(),
  DisposeGetxFieldsRule(),
  PreferNullableProviderTypesRule(),

  // Internationalization rules (ROADMAP_NEXT)
  PreferDateFormatRule(),
  PreferIntlNameRule(),
  PreferProvidingIntlDescriptionRule(),
  PreferProvidingIntlExamplesRule(),

  // Error handling rules (ROADMAP_NEXT)
  AvoidUncaughtFutureErrorsRule(),

  // Type safety rules (ROADMAP_NEXT)
  PreferExplicitTypeArgumentsRule(),

  // Image rules (roadmap_up_next)
  RequireImageLoadingPlaceholderRule(),
  RequireMediaLoadingStateRule(),
  RequirePdfLoadingIndicatorRule(),
  PreferClipboardFeedbackRule(),

  // Disposal rules (roadmap_up_next)
  RequireStreamSubscriptionCancelRule(),

  // Async rules (roadmap_up_next)
  AvoidDialogContextAfterAsyncRule(),
  RequireWebsocketMessageValidationRule(),
  RequireFeatureFlagDefaultRule(),
  PreferUtcForStorageRule(),
  RequireLocationTimeoutRule(),

  // Firebase/Maps rules (roadmap_up_next)
  PreferFirestoreBatchWriteRule(),
  AvoidFirestoreInWidgetBuildRule(),
  PreferFirebaseRemoteConfigDefaultsRule(),
  RequireFcmTokenRefreshHandlerRule(),
  RequireBackgroundMessageHandlerRule(),
  AvoidMapMarkersInBuildRule(),
  RequireMapIdleCallbackRule(),
  PreferMarkerClusteringRule(),

  // Accessibility rules (roadmap_up_next)
  RequireImageDescriptionRule(),
  AvoidSemanticsExclusionRule(),
  PreferMergeSemanticsRule(),
  RequireFocusIndicatorRule(),
  AvoidFlashingContentRule(),
  PreferAdequateSpacingRule(),
  AvoidMotionWithoutReduceRule(),
  RequireSemanticLabelIconsRule(),
  RequireAccessibleImagesRule(),
  AvoidAutoPlayMediaRule(),

  // Navigation rules (roadmap_up_next)
  RequireDeepLinkFallbackRule(),
  AvoidDeepLinkSensitiveParamsRule(),
  PreferTypedRouteParamsRule(),
  RequireStepperValidationRule(),
  RequireStepCountIndicatorRule(),
  RequireRefreshIndicatorOnListsRule(),

  // Animation rules (roadmap_up_next)
  PreferTweenSequenceRule(),
  RequireAnimationStatusListenerRule(),
  AvoidOverlappingAnimationsRule(),
  AvoidAnimationRebuildWasteRule(),
  PreferPhysicsSimulationRule(),

  // Platform-specific rules (roadmap_up_next)
  AvoidPlatformChannelOnWebRule(),
  RequireCorsHandlingRule(),
  PreferDeferredLoadingWebRule(),
  RequireMenuBarForDesktopRule(),
  AvoidTouchOnlyGesturesRule(),
  RequireWindowCloseConfirmationRule(),
  PreferNativeFileDialogsRule(),

  // Test rules (roadmap_up_next)
  RequireTestCleanupRule(),
  PreferTestVariantRule(),
  RequireAccessibilityTestsRule(),
  RequireAnimationTestsRule(),

  // Part 5 - SharedPreferences Security rules
  AvoidSharedPrefsSensitiveDataRule(),
  RequireSecureStorageForAuthRule(),
  RequireSharedPrefsNullHandlingRule(),
  RequireSharedPrefsKeyConstantsRule(),

  // Part 5 - sqflite Database rules
  RequireSqfliteWhereArgsRule(),
  RequireSqfliteTransactionRule(),
  RequireSqfliteErrorHandlingRule(),
  PreferSqfliteBatchRule(),
  RequireSqfliteCloseRule(),

  // Part 5 - Hive Database rules
  RequireHiveInitializationRule(),
  RequireHiveTypeAdapterRule(),
  RequireHiveBoxCloseRule(),
  PreferHiveEncryptionRule(),
  RequireHiveEncryptionKeySecureRule(),

  // Part 5 - Dio HTTP Client rules
  RequireDioTimeoutRule(),
  RequireDioErrorHandlingRule(),
  RequireDioInterceptorErrorHandlerRule(),
  PreferDioCancelTokenRule(),
  RequireDioSslPinningRule(),
  AvoidDioFormDataLeakRule(),

  // Part 5 - Stream/Future rules
  AvoidStreamInBuildRule(),
  RequireStreamControllerCloseRule(),
  AvoidMultipleStreamListenersRule(),
  RequireStreamErrorHandlingRule(),
  RequireFutureTimeoutRule(),

  // Part 5 - go_router Navigation rules
  AvoidGoRouterInlineCreationRule(),
  RequireGoRouterErrorHandlerRule(),
  RequireGoRouterRefreshListenableRule(),
  AvoidGoRouterStringPathsRule(),

  // Part 5 - Riverpod rules
  RequireRiverpodErrorHandlingRule(),
  AvoidRiverpodStateMutationRule(),
  PreferRiverpodSelectRule(),

  // Part 5 - cached_network_image rules
  RequireCachedImageDimensionsRule(),
  RequireCachedImagePlaceholderRule(),
  RequireCachedImageErrorWidgetRule(),

  // Part 5 - Geolocator rules
  RequireGeolocatorPermissionCheckRule(),
  RequireGeolocatorServiceEnabledRule(),
  RequireGeolocatorStreamCancelRule(),
  RequireGeolocatorErrorHandlingRule(),

  // Part 6 - State Management rules
  AvoidYieldInOnEventRule(),
  PreferConsumerOverProviderOfRule(),
  AvoidListenInAsyncRule(),
  PreferGetxBuilderRule(),
  EmitNewBlocStateInstancesRule(),
  AvoidBlocPublicFieldsRule(),
  AvoidBlocPublicMethodsRule(),
  RequireAsyncValueOrderRule(),
  RequireBlocSelectorRule(),
  PreferSelectorRule(),
  RequireGetxBindingRule(),

  // Provider dependency rules
  PreferProxyProviderRule(),
  RequireUpdateCallbackRule(),

  // GetX context safety rules
  AvoidGetxContextOutsideWidgetRule(),

  // Part 6 - Theming rules
  RequireDarkModeTestingRule(),
  AvoidElevationOpacityInDarkRule(),
  PreferThemeExtensionsRule(),

  // Part 6 - UI/UX rules
  PreferSkeletonOverSpinnerRule(),
  RequireEmptyResultsStateRule(),
  RequireSearchLoadingIndicatorRule(),
  RequireSearchDebounceRule(),
  RequirePaginationLoadingStateRule(),

  // Part 6 - Lifecycle rules
  AvoidWorkInPausedStateRule(),
  RequireResumeStateRefreshRule(),

  // Part 6 - Security rules
  RequireUrlValidationRule(),
  AvoidRedirectInjectionRule(),
  AvoidExternalStorageSensitiveRule(),
  PreferLocalAuthRule(),

  // Part 6 - Firebase rules
  RequireCrashlyticsUserIdRule(),
  RequireFirebaseAppCheckRule(),
  AvoidStoringUserDataInAuthRule(),

  // Part 6 - Collection/Performance rules
  PreferNullAwareElementsRule(),
  PreferIterableOperationsRule(),
  PreferInheritedWidgetCacheRule(),
  PreferLayoutBuilderOverMediaQueryRule(),

  // Part 6 - Flutter Widget rules
  RequireShouldRebuildRule(),
  RequireOrientationHandlingRule(),
  RequireWebRendererAwarenessRule(),

  // Part 6 - Additional rules
  RequireExifHandlingRule(),
  RequireRefreshIndicatorOnListsRule(),
  PreferAdaptiveDialogRule(),
  RequireSnackbarActionForUndoRule(),
  RequireContentTypeCheckRule(),
  AvoidWebsocketWithoutHeartbeatRule(),
  AvoidKeyboardOverlapRule(),
  RequireLocationTimeoutRule(),
  PreferCameraResolutionSelectionRule(),
  PreferAudioSessionConfigRule(),
  PreferDotShorthandRule(),
  AvoidTouchOnlyGesturesRule(),
  RequireFutureWaitErrorHandlingRule(),
  RequireStreamOnDoneRule(),
  RequireCompleterErrorHandlingRule(),

  // Package-specific rules (NEW)
  RequireGoogleSigninErrorHandlingRule(),
  RequireAppleSigninNonceRule(),
  RequireSupabaseErrorHandlingRule(),
  AvoidSupabaseAnonKeyInCodeRule(),
  RequireSupabaseRealtimeUnsubscribeRule(),
  RequireWebviewSslErrorHandlingRule(),
  AvoidWebviewFileAccessRule(),
  RequireWorkmanagerConstraintsRule(),
  RequireWorkmanagerResultReturnRule(),
  RequireCalendarTimezoneHandlingRule(),
  RequireKeyboardVisibilityDisposeRule(),
  RequireSpeechStopOnDisposeRule(),
  AvoidAppLinksSensitiveParamsRule(),
  RequireEnviedObfuscationRule(),
  AvoidOpenaiKeyInCodeRule(),
  RequireOpenaiErrorHandlingRule(),
  RequireSvgErrorHandlerRule(),
  RequireGoogleFontsFallbackRule(),
  PreferUuidV4Rule(),

  // Disposal pattern detection rules (NEW)
  RequireBlocManualDisposeRule(),
  RequireGetxWorkerDisposeRule(),
  RequireGetxPermanentCleanupRule(),
  RequireAnimationTickerDisposalRule(),
  RequireImageStreamDisposeRule(),
  RequireSseSubscriptionCancelRule(),

  // Late keyword rules (NEW)
  PreferLateFinalRule(),
  AvoidLateForNullableRule(),

  // go_router type safety rules (NEW)
  PreferGoRouterExtraTypedRule(),

  // Firebase Auth persistence rule (NEW)
  PreferFirebaseAuthPersistenceRule(),

  // Geolocator battery optimization rule (NEW)
  PreferGeolocatorDistanceFilterRule(),

  // Image picker OOM prevention (NEW)
  PreferImagePickerMaxDimensionsRule(),
];

class _SaropaLints extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) {
    // Read tier configuration from custom_lint.yaml:
    // custom_lint:
    //   saropa_lints:
    //     tier: recommended
    final LintOptions? saropaConfig = configs.rules['saropa_lints'];
    final String tier = saropaConfig?.json['tier'] as String? ?? 'essential';

    // Get all rules enabled for this tier
    final Set<String> tierRules = getRulesForTier(tier);

    return _allRules.where((LintRule rule) {
      final String ruleName = rule.code.name;
      final LintOptions? options = configs.rules[ruleName];

      // If explicitly configured in custom_lint.yaml, use that setting
      if (options != null) {
        return options.enabled;
      }

      // If enableAllLintRules is true, enable all rules
      if (configs.enableAllLintRules == true) {
        return true;
      }

      // Otherwise, use tier-based rules
      return tierRules.contains(ruleName);
    }).toList();
  }
}
