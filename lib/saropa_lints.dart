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
export 'package:saropa_lints/src/tiers.dart';

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
  FormatTestNameRule(),
  PreferCorrectSwitchLengthRule(),
  PreferCorrectTypeNameRule(),
  PreferReturningConditionalsRule(),
  AvoidExcessiveExpressionsRule(),
  MapKeysOrderingRule(),
  MatchClassNamePatternRule(),
  NewlineBeforeCaseRule(),
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
  MissingTestAssertionRule(),
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
  RequireFutureErrorHandlingRule(),
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
  RequireApiTimeoutRule(),
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
  RequireDatabaseCloseRule(),
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
