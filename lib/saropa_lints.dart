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

import 'package:saropa_lints/src/baseline/baseline_config.dart';
import 'package:saropa_lints/src/baseline/baseline_manager.dart';
import 'package:saropa_lints/src/rules/all_rules.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart';
import 'package:saropa_lints/src/tiers.dart';

// Export all rule classes for documentation
export 'package:saropa_lints/src/rules/all_rules.dart';
export 'package:saropa_lints/src/saropa_lint_rule.dart'
    show
        ImpactTracker,
        LintImpact,
        OwaspMapping,
        OwaspMobile,
        OwaspWeb,
        RuleTimingRecord,
        RuleTimingTracker,
        SaropaLintRule,
        ViolationRecord;
export 'package:saropa_lints/src/baseline/baseline_config.dart';
export 'package:saropa_lints/src/baseline/baseline_date.dart';
export 'package:saropa_lints/src/baseline/baseline_file.dart';
export 'package:saropa_lints/src/baseline/baseline_manager.dart';
export 'package:saropa_lints/src/baseline/baseline_paths.dart';
export 'package:saropa_lints/src/tiers.dart';
export 'package:saropa_lints/src/project_context.dart'
    show
        AstNodeCategory,
        AstNodeTypeRegistry,
        ContentFingerprint,
        ContentRegionIndex,
        ContentRegions,
        FileMetrics,
        FileMetricsCache,
        FileType,
        FileTypeDetector,
        IncrementalAnalysisTracker,
        initializeCacheManagement,
        LazyPattern,
        LazyPatternCache,
        LruCache,
        MemoryPressureHandler,
        PatternIndex,
        ProjectContext,
        RuleCost,
        RuleDependencyGraph,
        RuleExecutionStats,
        RulePatternInfo,
        RulePriorityInfo,
        RulePriorityQueue,
        SmartContentFilter,
        ViolationBatch;

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
  AvoidStoringContextRule(),
  AvoidContextAcrossAsyncRule(),
  AvoidContextAfterAwaitInStaticRule(),
  AvoidContextInAsyncStaticRule(),
  AvoidContextInStaticMethodsRule(),
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
  NoBooleanLiteralCompareRule(),
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
  // PreferEarlyReturnRule(), // Hidden in all_rules.dart
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
  AvoidMutableFieldInEquatableRule(),
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
  AvoidLongTestFilesRule(),
  AvoidMediumFilesRule(),
  AvoidMediumTestFilesRule(),
  AvoidVeryLongFilesRule(),
  AvoidVeryLongTestFilesRule(),
  PreferSmallFilesRule(),
  PreferSmallTestFilesRule(),
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
  AvoidParameterReassignmentRule(),
  AvoidParameterMutationRule(),
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
  AvoidPrintErrorRule(),
  // RequireFutureErrorHandlingRule merged into AvoidUncaughtFutureErrorsRule
  AvoidGenericExceptionsRule(),
  RequireErrorContextRule(),
  PreferResultPatternRule(),
  RequireAsyncErrorDocumentationRule(),
  RequireErrorBoundaryRule(),
  RequireErrorLoggingRule(),

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
  RequireIntlDateFormatLocaleRule(),
  RequireNumberFormatLocaleRule(),
  AvoidManualDateFormattingRule(),
  RequireIntlCurrencyFormatRule(),

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

  // Testing best practices rules (Section 5.31)
  PreferTestFindByKeyRule(),
  PreferSetupTeardownRule(),
  RequireTestDescriptionConventionRule(),
  PreferBlocTestPackageRule(),
  PreferMockVerifyRule(),

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
  PreferDescriptiveBoolNamesStrictRule(),
  PreferSnakeCaseFilesRule(),
  AvoidSmallTextRule(),
  PreferDocCommentsOverRegularRule(),
  PreferStraightApostropheRule(),
  PreferDocCurlyApostropheRule(),

  // =========================================================================
  // NEW STYLISTIC RULES v2.5.0 (76+ opinionated rules with opposites)
  // =========================================================================

  // Widget & UI stylistic rules (stylistic_widget_rules.dart)
  PreferSizedBoxOverContainerRule(),
  PreferContainerOverSizedBoxRule(),
  PreferTextRichOverRichTextRule(),
  PreferRichTextOverTextRichRule(),
  PreferEdgeInsetsSymmetricRule(),
  PreferEdgeInsetsOnlyRule(),
  PreferBorderRadiusCircularRule(),
  PreferExpandedOverFlexibleRule(),
  PreferFlexibleOverExpandedRule(),
  PreferMaterialThemeColorsRule(),
  PreferExplicitColorsRule(),

  // Null handling & collection stylistic rules (stylistic_null_collection_rules.dart)
  PreferNullAwareAssignmentRule(),
  PreferExplicitNullAssignmentRule(),
  PreferIfNullOverTernaryRule(),
  PreferTernaryOverIfNullRule(),
  PreferLateOverNullableRule(),
  PreferNullableOverLateRule(),
  PreferSpreadOverAddAllRule(),
  PreferAddAllOverSpreadRule(),
  PreferCollectionIfOverTernaryRule(),
  PreferTernaryOverCollectionIfRule(),
  PreferWhereTypeOverWhereIsRule(),
  PreferMapEntriesIterationRule(),
  PreferKeysIterationRule(),

  // Control flow stylistic rules (stylistic_control_flow_rules.dart)
  PreferSingleExitPointRule(),
  PreferGuardClausesRule(),
  PreferPositiveConditionsFirstRule(),
  PreferSwitchStatementRule(),
  PreferCascadeOverChainedRule(),
  PreferChainedOverCascadeRule(),
  PreferExhaustiveEnumsRule(),
  PreferDefaultEnumCaseRule(),
  PreferAsyncOnlyWhenAwaitingRule(),
  PreferAwaitOverThenRule(),
  PreferThenOverAwaitRule(),
  PreferSyncOverAsyncWhereSimpleRule(),

  // Whitespace & constructor stylistic rules (stylistic_whitespace_constructor_rules.dart)
  // PreferBlankLineBeforeReturnRule(), // Not defined
  PreferNoBlankLineBeforeReturnRule(),
  PreferBlankLineAfterDeclarationsRule(),
  PreferCompactDeclarationsRule(),
  PreferBlankLinesBetweenMembersRule(),
  PreferCompactClassMembersRule(),
  PreferNoBlankLineInsideBlocksRule(),
  PreferSingleBlankLineMaxRule(),
  PreferSuperParametersRule(),
  PreferInitializingFormalsRule(),
  PreferConstructorBodyAssignmentRule(),
  PreferFactoryForValidationRule(),
  PreferConstructorAssertionRule(),
  PreferRequiredBeforeOptionalRule(),
  PreferGroupedByPurposeRule(),
  PreferRethrowOverThrowERule(),

  // Error handling & testing stylistic rules (stylistic_error_testing_rules.dart)
  PreferSpecificExceptionsRule(),
  PreferGenericExceptionRule(),
  PreferExceptionSuffixRule(),
  PreferErrorSuffixRule(),
  PreferOnOverCatchRule(),
  PreferCatchOverOnRule(),
  PreferGivenWhenThenCommentsRule(),
  PreferSelfDocumentingTestsRule(),
  PreferExpectOverAssertInTestsRule(),
  PreferSingleExpectationPerTestRule(),
  PreferGroupedExpectationsRule(),
  PreferTestNameShouldWhenRule(),
  PreferTestNameDescriptiveRule(),

  // Additional stylistic rules (stylistic_additional_rules.dart)
  PreferInterpolationOverConcatenationRule(),
  PreferConcatenationOverInterpolationRule(),
  PreferDoubleQuotesRule(),
  PreferAbsoluteImportsRule(),
  PreferGroupedImportsRule(),
  PreferFlatImportsRule(),
  PreferFieldsBeforeMethodsRule(),
  PreferMethodsBeforeFieldsRule(),
  PreferStaticMembersFirstRule(),
  PreferInstanceMembersFirstRule(),
  PreferPublicMembersFirstRule(),
  PreferPrivateMembersFirstRule(),
  PreferVarOverExplicitTypeRule(),
  PreferObjectOverDynamicRule(),
  PreferDynamicOverObjectRule(),
  PreferLowerCamelCaseConstantsRule(),
  PreferCamelCaseMethodNamesRule(),
  PreferDescriptiveVariableNamesRule(),
  PreferConciseVariableNamesRule(),
  PreferExplicitThisRule(),
  PreferImplicitBooleanComparisonRule(),
  PreferExplicitBooleanComparisonRule(),

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
  // ProperGetxSuperCallsRule(), // Hidden in all_rules.dart
  // AlwaysRemoveGetxListenerRule(), // Hidden in all_rules.dart
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
  // GetX rules (hidden in all_rules.dart)
  // RequireGetxControllerDisposeRule(),
  // AvoidObsOutsideControllerRule(),
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
  RequireKeyForCollectionRule(),
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

  // GetX Build rules (Phase 2) - hidden in all_rules.dart
  // AvoidGetxRxInsideBuildRule(),
  // AvoidMutableRxVariablesRule(),

  // Remaining ROADMAP_NEXT rules
  DisposeProvidedInstancesRule(),
  // DisposeGetxFieldsRule(), // Hidden in all_rules.dart
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
  AvoidCircularImportsRule(),
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
  AvoidSqfliteReservedWordsRule(),

  // Part 5 - Hive Database rules
  RequireHiveInitializationRule(),
  RequireHiveTypeAdapterRule(),
  RequireHiveBoxCloseRule(),
  PreferHiveEncryptionRule(),
  RequireHiveEncryptionKeySecureRule(),
  AvoidHiveFieldIndexReuseRule(),

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
  // PreferGetxBuilderRule(), // Hidden in all_rules.dart
  EmitNewBlocStateInstancesRule(),
  AvoidBlocPublicFieldsRule(),
  AvoidBlocPublicMethodsRule(),
  RequireAsyncValueOrderRule(),
  RequireBlocSelectorRule(),
  PreferSelectorRule(),
  // RequireGetxBindingRule(), // Hidden in all_rules.dart

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

  // =========================================================================
  // NEW RULES v2.3.10
  // =========================================================================

  // Test rules
  AvoidTestPrintStatementsRule(),
  RequireMockHttpClientRule(),

  // Async rules
  AvoidFutureThenInAsyncRule(),
  AvoidUnawaitedFutureRule(),

  // Forms rules
  RequireTextInputTypeRule(),
  PreferTextInputActionRule(),
  RequireFormKeyInStatefulWidgetRule(),

  // Network rules
  PreferTimeoutOnRequestsRule(),
  PreferDioOverHttpRule(),

  // Error handling rules
  AvoidCatchAllRule(),
  AvoidCatchExceptionAloneRule(),

  // State management rules
  AvoidBlocContextDependencyRule(),
  AvoidProviderValueRebuildRule(),

  // Lifecycle rules
  RequireDidUpdateWidgetCheckRule(),

  // Equatable rules
  RequireEquatableCopyWithRule(),

  // Notification rules
  AvoidNotificationSameIdRule(),

  // Internationalization rules
  RequireIntlPluralRulesRule(),

  // Image rules
  PreferCachedImageCacheManagerRule(),
  RequireImageCacheDimensionsRule(),

  // Navigation rules
  PreferUrlLauncherUriOverStringRule(),
  AvoidGoRouterPushReplacementConfusionRule(),

  // Widget rules
  AvoidStackWithoutPositionedRule(),
  AvoidExpandedOutsideFlexRule(),
  PreferExpandedAtCallSiteRule(),

  // =========================================================================
  // NEW RULES v2.3.11
  // =========================================================================

  // Test rules
  RequireTestWidgetPumpRule(),
  RequireIntegrationTestTimeoutRule(),

  // Hive rules
  RequireHiveFieldDefaultValueRule(),
  RequireHiveAdapterRegistrationOrderRule(),
  RequireHiveNestedObjectAdapterRule(),
  AvoidHiveBoxNameCollisionRule(),

  // Security rules
  AvoidApiKeyInCodeRule(),
  AvoidStoringSensitiveUnencryptedRule(),

  // OWASP Coverage Gap Rules (v3.2.0)
  AvoidIgnoringSslErrorsRule(),
  RequireHttpsOnlyRule(),
  AvoidUnsafeDeserializationRule(),
  AvoidUserControlledUrlsRule(),
  RequireCatchLoggingRule(),

  // State management rules
  AvoidRiverpodNotifierInBuildRule(),
  RequireRiverpodAsyncValueGuardRule(),
  AvoidBlocBusinessLogicInUiRule(),

  // Navigation rules
  RequireUrlLauncherEncodingRule(),
  AvoidNestedRoutesWithoutParentRule(),

  // Equatable rules
  RequireCopyWithNullHandlingRule(),

  // Internationalization rules
  RequireIntlArgsMatchRule(),
  AvoidStringConcatenationForL10nRule(),

  // Performance rules
  AvoidBlockingDatabaseUiRule(),
  AvoidMoneyArithmeticOnDoubleRule(),
  AvoidRebuildOnScrollRule(),

  // Error handling rules
  AvoidExceptionInConstructorRule(),
  RequireCacheKeyDeterminismRule(),
  RequirePermissionPermanentDenialHandlingRule(),

  // Dependency injection rules
  RequireGetItRegistrationOrderRule(),
  RequireDefaultConfigRule(),

  // Widget rules
  AvoidBuilderIndexOutOfBoundsRule(),

  // =========================================================================
  // v2.4.0 - Apple Platform Rules (76 rules)
  // See doc/guides/apple_platform_rules.md for documentation
  // =========================================================================

  // iOS Core Rules
  PreferIosSafeAreaRule(),
  AvoidIosHardcodedStatusBarRule(),
  PreferIosHapticFeedbackRule(),
  RequireIosPlatformCheckRule(),
  AvoidIosBackgroundFetchAbuseRule(),
  RequireAppleSignInRule(),
  RequireIosBackgroundModeRule(),
  AvoidIos13DeprecationsRule(),
  AvoidIosSimulatorOnlyCodeRule(),
  RequireIosMinimumVersionCheckRule(),
  AvoidIosDeprecatedUikitRule(),
  RequireIosDynamicIslandSafeZonesRule(),
  RequireIosDeploymentTargetConsistencyRule(),
  RequireIosSceneDelegateAwarenessRule(),

  // App Store Review Rules
  RequireIosAppTrackingTransparencyRule(),
  RequireIosFaceIdUsageDescriptionRule(),
  RequireIosPhotoLibraryAddUsageRule(),
  AvoidIosInAppBrowserForAuthRule(),
  RequireIosAppReviewPromptTimingRule(),
  RequireIosReviewPromptFrequencyRule(),
  RequireIosReceiptValidationRule(),
  RequireIosAgeRatingConsiderationRule(),
  AvoidIosMisleadingPushNotificationsRule(),
  RequireIosPermissionDescriptionRule(),
  RequireIosPrivacyManifestRule(),
  RequireHttpsForIosRule(),

  // Security & Authentication Rules
  RequireIosKeychainAccessibilityRule(),
  RequireIosKeychainSyncAwarenessRule(),
  RequireIosKeychainForCredentialsRule(),
  RequireIosCertificatePinningRule(),
  RequireIosBiometricFallbackRule(),
  RequireIosHealthKitAuthorizationRule(),
  AvoidIosHardcodedBundleIdRule(),
  AvoidIosDebugCodeInReleaseRule(),

  // Platform Integration Rules
  RequireIosPushNotificationCapabilityRule(),
  RequireIosBackgroundAudioCapabilityRule(),
  RequireIosBackgroundRefreshDeclarationRule(),
  RequireIosAppGroupCapabilityRule(),
  RequireIosSiriIntentDefinitionRule(),
  RequireIosWidgetExtensionCapabilityRule(),
  RequireIosLiveActivitiesSetupRule(),
  RequireIosCarplaySetupRule(),
  RequireIosCallkitIntegrationRule(),
  RequireIosNfcCapabilityCheckRule(),
  RequireIosMethodChannelCleanupRule(),
  AvoidIosForceUnwrapInCallbacksRule(),
  RequireMethodChannelErrorHandlingRule(),
  PreferIosAppIntentsFrameworkRule(),

  // Device & Hardware Rules
  AvoidIosHardcodedDeviceModelRule(),
  RequireIosOrientationHandlingRule(),
  RequireIosPhotoLibraryLimitedAccessRule(),
  AvoidIosContinuousLocationTrackingRule(),
  RequireIosLifecycleHandlingRule(),
  RequireIosPromotionDisplaySupportRule(),
  RequireIosPasteboardPrivacyHandlingRule(),
  PreferIosStoreKit2Rule(),

  // Data & Storage Rules
  RequireIosDatabaseConflictResolutionRule(),
  RequireIosIcloudKvstoreLimitationsRule(),
  RequireIosShareSheetUtiDeclarationRule(),
  RequireIosAppClipSizeLimitRule(),
  RequireIosAtsExceptionDocumentationRule(),
  RequireIosLocalNotificationPermissionRule(),

  // Deep Linking Rules
  RequireUniversalLinkValidationRule(),
  RequireIosUniversalLinksDomainMatchingRule(),

  // macOS Platform Rules
  PreferMacosMenuBarIntegrationRule(),
  PreferMacosKeyboardShortcutsRule(),
  RequireMacosWindowSizeConstraintsRule(),
  RequireMacosWindowRestorationRule(),
  RequireMacosFileAccessIntentRule(),
  RequireMacosHardenedRuntimeRule(),
  RequireMacosSandboxEntitlementsRule(),
  AvoidMacosDeprecatedSecurityApisRule(),
  AvoidMacosCatalystUnsupportedApisRule(),
  AvoidMacosFullDiskAccessRule(),
  PreferCupertinoForIosRule(),
  RequireIosAccessibilityLabelsRule(),

  // =========================================================================
  // v2.4.0 Additional Rules - Background Processing, Notifications, Payments
  // =========================================================================

  // Background Processing Rules
  AvoidLongRunningIsolatesRule(),
  RequireWorkmanagerForBackgroundRule(),
  RequireNotificationForLongTasksRule(),
  PreferBackgroundSyncRule(),
  RequireSyncErrorRecoveryRule(),

  // Notification Rules
  PreferDelayedPermissionPromptRule(),
  AvoidNotificationSpamRule(),

  // In-App Purchase Rules
  RequirePurchaseVerificationRule(),
  RequirePurchaseRestorationRule(),

  // iOS Platform Enhancement Rules
  AvoidIosWifiOnlyAssumptionRule(),
  RequireIosLowPowerModeHandlingRule(),
  RequireIosAccessibilityLargeTextRule(),
  PreferIosContextMenuRule(),
  RequireIosQuickNoteAwarenessRule(),
  AvoidIosHardcodedKeyboardHeightRule(),
  RequireIosMultitaskingSupportRule(),
  PreferIosSpotlightIndexingRule(),
  RequireIosDataProtectionRule(),
  AvoidIosBatteryDrainPatternsRule(),
  RequireIosEntitlementsRule(),
  RequireIosLaunchStoryboardRule(),
  RequireIosVersionCheckRule(),
  RequireIosFocusModeAwarenessRule(),
  PreferIosHandoffSupportRule(),
  RequireIosVoiceoverGestureCompatibilityRule(),

  // macOS Platform Enhancement Rules
  RequireMacosSandboxExceptionsRule(),
  AvoidMacosHardenedRuntimeViolationsRule(),
  RequireMacosAppTransportSecurityRule(),
  RequireMacosNotarizationReadyRule(),
  RequireMacosEntitlementsRule(),

  // v2.6.0 rules (ROADMAP_NEXT implementation)
  // Code quality
  PreferReturningConditionalExpressionsRule(),

  // Riverpod rules
  PreferRiverpodAutoDisposeRule(),
  PreferRiverpodFamilyForParamsRule(),

  // GetX rules
  AvoidGetxGlobalNavigationRule(),
  RequireGetxBindingRoutesRule(),

  // Dio rules
  RequireDioResponseTypeRule(),
  RequireDioRetryInterceptorRule(),
  PreferDioTransformerRule(),

  // GoRouter rules
  PreferShellRouteSharedLayoutRule(),
  RequireStatefulShellRouteTabsRule(),
  RequireGoRouterFallbackRouteRule(),

  // SQLite rules
  PreferSqfliteSingletonRule(),
  PreferSqfliteColumnConstantsRule(),

  // Freezed rules
  RequireFreezedJsonConverterRule(),
  RequireFreezedLintPackageRule(),

  // Geolocation rules
  PreferGeolocatorAccuracyAppropriateRule(),
  PreferGeolocatorLastKnownRule(),

  // Image picker rules
  PreferImagePickerMultiSelectionRule(),

  // Notification rules
  RequireNotificationActionHandlingRule(),

  // Error handling rules
  RequireFinallyCleanupRule(),

  // DI rules
  RequireDiScopeAwarenessRule(),

  // Equatable rules
  RequireDeepEqualityCollectionsRule(),
  AvoidEquatableDatetimeRule(),
  PreferUnmodifiableCollectionsRule(),

  // Hive rules
  PreferHiveValueListenableRule(),

  // NEW ROADMAP STAR RULES
  // Bloc/Cubit rules
  AvoidPassingBlocToBlocRule(),
  AvoidPassingBuildContextToBlocsRule(),
  AvoidReturningValueFromCubitMethodsRule(),
  RequireBlocRepositoryInjectionRule(),
  PreferBlocHydrationRule(),

  // GetX rules
  AvoidGetxDialogSnackbarInControllerRule(),
  RequireGetxLazyPutRule(),

  // Hive/SharedPrefs rules
  PreferHiveLazyBoxRule(),
  AvoidHiveBinaryStorageRule(),
  RequireSharedPrefsPrefixRule(),
  PreferSharedPrefsAsyncApiRule(),
  AvoidSharedPrefsInIsolateRule(),

  // Stream rules
  PreferStreamDistinctRule(),
  PreferBroadcastStreamRule(),

  // Async/Build rules
  AvoidFutureInBuildRule(),
  RequireMountedCheckAfterAwaitRule(),
  AvoidAsyncInBuildRule(),
  PreferAsyncInitStateRule(),

  // Widget lifecycle rules
  RequireWidgetsBindingCallbackRule(),

  // Navigation rules
  PreferRouteSettingsNameRule(),

  // Internationalization rules
  PreferNumberFormatRule(),
  ProvideCorrectIntlArgsRule(),

  // Package-specific rules
  AvoidFreezedForLogicClassesRule(),

  // Disposal rules
  DisposeClassFieldsRule(),

  // State management rules
  PreferChangeNotifierProxyProviderRule(),

  // =========================================================================
  // NEW RULES v4.1.5 (24 new rules)
  // =========================================================================

  // Dependency Injection rules
  AvoidDiInWidgetsRule(),
  PreferAbstractionInjectionRule(),

  // Accessibility rules
  PreferLargeTouchTargetsRule(),
  AvoidTimeLimitsRule(),
  RequireDragAlternativesRule(),

  // Flutter widget rules
  AvoidGlobalKeysInStateRule(),
  AvoidStaticRouteConfigRule(),

  // State management rules
  RequireFlutterRiverpodNotRiverpodRule(),
  AvoidRiverpodNavigationRule(),

  // Firebase rules
  RequireFirebaseErrorHandlingRule(),
  AvoidFirebaseRealtimeInBuildRule(),

  // Security rules
  RequireSecureStorageErrorHandlingRule(),
  AvoidSecureStorageLargeDataRule(),

  // Navigation rules
  AvoidNavigatorContextIssueRule(),
  RequirePopResultTypeRule(),
  AvoidPushReplacementMisuseRule(),
  AvoidNestedNavigatorsMisuseRule(),
  RequireDeepLinkTestingRule(),

  // Internationalization rules
  AvoidStringConcatenationL10nRule(),
  PreferIntlMessageDescriptionRule(),
  AvoidHardcodedLocaleStringsRule(),

  // Async rules
  RequireNetworkStatusCheckRule(),
  AvoidSyncOnEveryChangeRule(),
  RequirePendingChangesIndicatorRule(),

  // =========================================================================
  // NEW RULES v4.1.6 (14 new rules)
  // =========================================================================

  // Logging rules (debug_rules.dart)
  AvoidPrintInReleaseRule(),
  RequireStructuredLoggingRule(),
  AvoidSensitiveInLogsRule(),

  // Platform rules (platform_rules.dart)
  RequirePlatformCheckRule(),
  PreferPlatformIoConditionalRule(),
  AvoidWebOnlyDependenciesRule(),
  PreferFoundationPlatformCheckRule(),

  // JSON/API rules (json_datetime_rules.dart)
  RequireDateFormatSpecificationRule(),
  PreferIso8601DatesRule(),
  AvoidOptionalFieldCrashRule(),
  PreferExplicitJsonKeysRule(),

  // Configuration rules (config_rules.dart)
  AvoidHardcodedConfigRule(),
  AvoidMixedEnvironmentsRule(),

  // Lifecycle rules (lifecycle_rules.dart)
  RequireLateInitializationInInitStateRule(),

  // =========================================================================
  // NEW RULES v4.1.7 (25 new rules)
  // =========================================================================

  // State management rules (v417_state_rules.dart)
  AvoidRiverpodForNetworkOnlyRule(),
  AvoidLargeBlocRule(),
  AvoidOverengineeredBlocStatesRule(),
  AvoidGetxStaticContextRule(),
  AvoidTightCouplingWithGetxRule(),

  // Performance rules (v417_performance_rules.dart)
  PreferElementRebuildRule(),
  RequireIsolateForHeavyRule(),
  AvoidFinalizerMisuseRule(),
  AvoidJsonInMainRule(),

  // Security rules (v417_security_rules.dart)
  AvoidSensitiveDataInClipboardRule(),
  RequireClipboardPasteValidationRule(),
  AvoidEncryptionKeyInMemoryRule(),

  // Caching rules (v417_caching_rules.dart)
  RequireCacheExpirationRule(),
  AvoidUnboundedCacheGrowthRule(),
  RequireCacheKeyUniquenessRule(),

  // Testing rules (v417_testing_rules.dart)
  RequireDialogTestsRule(),
  PreferFakePlatformRule(),
  RequireTestDocumentationRule(),

  // Widget rules (v417_widget_rules.dart)
  PreferCustomSingleChildLayoutRule(),
  RequireLocaleForTextRule(),
  RequireDialogBarrierConsiderationRule(),
  PreferFeatureFolderStructureRule(),

  // Misc rules (v417_misc_rules.dart)
  RequireWebsocketReconnectionRule(),
  RequireCurrencyCodeWithAmountRule(),
  PreferLazySingletonRegistrationRule(),

  // =========================================================================
  // v4.2.0 ROADMAP ⭐ Rules
  // =========================================================================

  // Android rules (android_rules.dart)
  RequireAndroidPermissionRequestRule(),
  AvoidAndroidTaskAffinityDefaultRule(),
  RequireAndroid12SplashRule(),
  PreferPendingIntentFlagsRule(),
  AvoidAndroidCleartextTrafficRule(),
  RequireAndroidBackupRulesRule(),

  // IAP rules (iap_rules.dart)
  AvoidPurchaseInSandboxProductionRule(),
  RequireSubscriptionStatusCheckRule(),
  RequirePriceLocalizationRule(),

  // URL Launcher rules (url_launcher_rules.dart)
  RequireUrlLauncherCanLaunchCheckRule(),
  AvoidUrlLauncherSimulatorTestsRule(),
  PreferUrlLauncherFallbackRule(),

  // Permission rules (permission_rules.dart)
  RequireLocationPermissionRationaleRule(),
  RequireCameraPermissionCheckRule(),
  PreferImageCroppingRule(),

  // Connectivity rules (connectivity_rules.dart)
  RequireConnectivityErrorHandlingRule(),

  // Geolocator rules (geolocator_rules.dart)
  RequireGeolocatorBatteryAwarenessRule(),

  // SQLite rules (sqflite_rules.dart)
  AvoidSqfliteTypeMismatchRule(),

  // Firebase rules (firebase_rules.dart)
  RequireFirestoreIndexRule(),

  // Notification rules (notification_rules.dart)
  PreferNotificationGroupingRule(),
  AvoidNotificationSilentFailureRule(),

  // Hive rules (hive_rules.dart)
  RequireHiveMigrationStrategyRule(),

  // Async rules (async_rules.dart)
  AvoidStreamSyncEventsRule(),
  AvoidSequentialAwaitsRule(),

  // File handling rules (file_handling_rules.dart)
  PreferStreamingForLargeFilesRule(),
  RequireFilePathSanitizationRule(),

  // Error handling rules (error_handling_rules.dart)
  RequireAppStartupErrorHandlingRule(),
  AvoidAssertInProductionRule(),

  // Accessibility rules (accessibility_rules.dart)
  PreferFocusTraversalOrderRule(),

  // UI/UX rules (ui_ux_rules.dart)
  AvoidLoadingFlashRule(),

  // Performance rules (performance_rules.dart)
  AvoidAnimationInLargeListRule(),
  PreferLazyLoadingImagesRule(),

  // JSON/DateTime rules (json_datetime_rules.dart)
  RequireJsonSchemaValidationRule(),
  PreferJsonSerializableRule(),

  // Forms rules (forms_rules.dart)
  PreferRegexValidationRule(),

  // Package-specific rules (package_specific_rules.dart)
  PreferTypedPrefsWrapperRule(),
  PreferFreezedForDataClassesRule(),
];

// =============================================================================
// RULE FILTERING CACHE (Performance Optimization)
// =============================================================================
//
// Caches the filtered rule list per tier+config combination to avoid
// re-filtering 1400+ rules on every file analysis. The filter operation
// itself is O(n) and was being called for EVERY file in the project.
//
// Cache invalidation: The cache is keyed by tier name. If the user changes
// their tier or rule overrides, they need to restart the analysis server.
// This is acceptable since config changes require a restart anyway.
// =============================================================================

/// Cached filtered rules to avoid re-filtering on every file.
List<LintRule>? _cachedFilteredRules;

/// The tier that was used to compute the cached rules.
String? _cachedTier;

/// Whether enableAllLintRules was set when cache was computed.
bool? _cachedEnableAll;

/// Hash of individual rule overrides when cache was computed.
/// This ensures cache invalidation when explicit rule configs change.
int? _cachedRulesHash;

class _SaropaLints extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) {
    // Read tier configuration from custom_lint.yaml:
    // custom_lint:
    //   saropa_lints:
    //     tier: recommended
    //     baseline:
    //       file: "saropa_baseline.json"
    //       paths: ["lib/legacy/"]
    final LintOptions? saropaConfig = configs.rules['saropa_lints'];
    final String tier = saropaConfig?.json['tier'] as String? ?? 'essential';
    final bool enableAll = configs.enableAllLintRules == true;

    // =========================================================================
    // BASELINE CONFIGURATION
    // =========================================================================
    // Initialize baseline manager for suppressing legacy violations.
    // This allows brownfield projects to adopt linting without being
    // overwhelmed by existing issues.
    final baselineConfig = BaselineConfig.fromYaml(
      saropaConfig?.json['baseline'],
    );
    if (baselineConfig.isEnabled) {
      BaselineManager.initialize(baselineConfig);
    }

    // =========================================================================
    // PERFORMANCE INFRASTRUCTURE INITIALIZATION
    // =========================================================================
    // Initialize caches, string interning, and memory management on first run.
    // This happens once per analysis session, not per file.
    if (_cachedFilteredRules == null) {
      // Initialize cache management with memory pressure handling
      initializeCacheManagement(
        maxFileContentCache: 500,
        maxMetricsCache: 2000,
        maxLocationCache: 2000,
        memoryThresholdMb: 512,
      );

      // Pre-intern common Dart/Flutter strings for memory efficiency
      StringInterner.preInternCommon();

      // Register rule groups for batch execution
      _registerRuleGroups();
    }

    // =========================================================================
    // PERFORMANCE: Return cached rules if config hasn't changed
    // =========================================================================
    // This avoids re-filtering 1400+ rules for every single file.
    // The filter is computed ONCE per analysis session, not per file.
    // IMPORTANT: Hash includes individual rule overrides to ensure cache
    // invalidation when explicit rules are enabled/disabled.
    final int rulesHash = Object.hashAll(
      configs.rules.entries
          .where((e) => e.key != 'saropa_lints') // Exclude meta-config
          .map((e) => '${e.key}:${e.value.enabled}'),
    );
    if (_cachedFilteredRules != null &&
        _cachedTier == tier &&
        _cachedEnableAll == enableAll &&
        _cachedRulesHash == rulesHash) {
      return _cachedFilteredRules!;
    }

    // Get all rules enabled for this tier
    final Set<String> tierRules = getRulesForTier(tier);

    // Filter rules based on tier and explicit overrides
    final List<LintRule> filteredRules = _allRules.where((LintRule rule) {
      final String ruleName = rule.code.name;

      // Check canonical name first
      LintOptions? options = configs.rules[ruleName];

      // If not found, check aliases (for SaropaLintRule instances)
      if (options == null && rule is SaropaLintRule) {
        for (final String alias in rule.configAliases) {
          options = configs.rules[alias];
          if (options != null) break;
        }
      }

      // If explicitly configured in custom_lint.yaml, use that setting
      if (options != null) {
        return options.enabled;
      }

      // If enableAllLintRules is true, enable all rules
      if (enableAll) {
        return true;
      }

      // Otherwise, use tier-based rules
      return tierRules.contains(ruleName);
    }).toList();

    // =========================================================================
    // RULE PRIORITY ORDERING (Performance Optimization)
    // =========================================================================
    // Sort rules by estimated execution cost so fast rules run first.
    // This improves perceived performance and allows early termination
    // strategies in the future.
    filteredRules.sort((a, b) {
      final costA = _getRuleCost(a);
      final costB = _getRuleCost(b);
      return costA.index.compareTo(costB.index);
    });

    // =========================================================================
    // BUILD PATTERN INDEX (Performance Optimization)
    // =========================================================================
    // Build a combined index of all required patterns across rules.
    // This allows single-pass content scanning instead of per-rule scanning.
    final List<RulePatternInfo> patternInfos = filteredRules
        .whereType<SaropaLintRule>()
        .map((SaropaLintRule rule) => RulePatternInfo(
              name: rule.code.name,
              patterns: rule.requiredPatterns,
            ))
        .toList();
    PatternIndex.build(patternInfos);

    // =========================================================================
    // SET RULE CONFIG HASH (Performance Optimization)
    // =========================================================================
    // Compute a hash of the current rule configuration for incremental analysis.
    // If the config changes, all cached analysis results are invalidated.
    final int configHash = Object.hashAll(<Object>[
      tier,
      enableAll,
      ...filteredRules.map((LintRule r) => r.code.name),
    ]);
    IncrementalAnalysisTracker.setRuleConfig(configHash);

    // =========================================================================
    // CONFLICTING RULE DETECTION
    // =========================================================================
    // Warn when mutually exclusive stylistic rules are both enabled.
    // These rule pairs have opposite effects and should not be used together.
    _checkConflictingRules(filteredRules);

    // Cache the result for subsequent files
    _cachedFilteredRules = filteredRules;
    _cachedTier = tier;
    _cachedEnableAll = enableAll;
    _cachedRulesHash = rulesHash;

    return filteredRules;
  }
}

/// Conflicting rule pairs that should not be enabled together.
///
/// These are stylistic choices where enabling both makes no sense.
/// Each pair contains two mutually exclusive rules.
const List<List<String>> _conflictingRulePairs = <List<String>>[
  // Type inference vs explicit types
  <String>['avoid_inferrable_type_arguments', 'prefer_explicit_type_arguments'],
  // Import style preferences
  <String>['prefer_relative_imports', 'always_use_package_imports'],
];

/// Check for conflicting rules and print a warning if both are enabled.
///
/// This helps users catch configuration mistakes where they've enabled
/// two mutually exclusive stylistic rules.
void _checkConflictingRules(List<LintRule> enabledRules) {
  final Set<String> enabledNames =
      enabledRules.map((LintRule rule) => rule.code.name).toSet();

  for (final List<String> pair in _conflictingRulePairs) {
    final String rule1 = pair[0];
    final String rule2 = pair[1];

    if (enabledNames.contains(rule1) && enabledNames.contains(rule2)) {
      // Use stderr to output warning without breaking analysis
      // ignore: avoid_print
      print(
        '[saropa_lints] WARNING: Conflicting rules enabled: '
        '$rule1 and $rule2. '
        'These rules have opposite effects - disable one.',
      );
    }
  }
}

/// Get the execution cost of a rule.
///
/// If the rule is a [SaropaLintRule], use its declared cost.
/// Otherwise, default to medium cost.
RuleCost _getRuleCost(LintRule rule) {
  if (rule is SaropaLintRule) {
    return rule.cost;
  }
  // Non-Saropa rules default to medium cost
  return RuleCost.medium;
}

/// Register rule groups for batch execution optimization.
///
/// Groups related rules that share patterns and can benefit from
/// shared setup/teardown and intermediate results.
void _registerRuleGroups() {
  // Async rules - share Future/async/await patterns
  RuleGroupExecutor.registerGroup(RuleGroup(
    name: 'async_rules',
    rules: const {
      'avoid_slow_async_io',
      'unawaited_futures',
      'await_only_futures',
      'prefer_async_await',
      'avoid_async_void',
      'avoid_unnecessary_async',
      'missing_await_in_async',
    },
    sharedPatterns: const {'async', 'await', 'Future'},
    priority: 10,
  ));

  // Widget rules - share StatelessWidget/StatefulWidget patterns
  RuleGroupExecutor.registerGroup(RuleGroup(
    name: 'widget_rules',
    rules: const {
      'avoid_stateless_widget_initialized_fields',
      'avoid_state_constructors',
      'prefer_const_constructors_in_immutables',
      'avoid_unnecessary_setstate',
      'use_build_context_synchronously',
      'prefer_stateless_widget',
    },
    sharedPatterns: const {
      'StatelessWidget',
      'StatefulWidget',
      'State<',
      'build('
    },
    priority: 20,
  ));

  // Context rules - share BuildContext patterns
  RuleGroupExecutor.registerGroup(RuleGroup(
    name: 'context_rules',
    rules: const {
      'use_build_context_synchronously',
      'avoid_context_across_async_gaps',
      'prefer_context_extension',
    },
    sharedPatterns: const {'BuildContext', 'context'},
    priority: 30,
  ));

  // Dispose rules - share dispose/controller patterns
  RuleGroupExecutor.registerGroup(RuleGroup(
    name: 'dispose_rules',
    rules: const {
      'close_sinks',
      'cancel_subscriptions',
      'dispose_controllers',
      'require_dispose_method',
    },
    sharedPatterns: const {
      'dispose',
      'Controller',
      'StreamSubscription',
      'StreamController'
    },
    priority: 40,
  ));

  // Test rules - share test patterns
  RuleGroupExecutor.registerGroup(RuleGroup(
    name: 'test_rules',
    rules: const {
      'avoid_test_sleep',
      'avoid_find_by_text',
      'require_test_keys',
      'prefer_pump_and_settle',
      'prefer_test_find_by_key',
    },
    sharedPatterns: const {'test(', 'testWidgets(', 'expect(', 'find.'},
    priority: 50,
  ));

  // Security rules - share security-sensitive patterns
  RuleGroupExecutor.registerGroup(RuleGroup(
    name: 'security_rules',
    rules: const {
      'avoid_weak_cryptographic_algorithms',
      'avoid_hardcoded_credentials',
      'avoid_dynamic_sql',
      'avoid_insecure_random',
    },
    sharedPatterns: const {
      'password',
      'secret',
      'token',
      'credential',
      'MD5',
      'SHA1'
    },
    priority: 60,
  ));
}
