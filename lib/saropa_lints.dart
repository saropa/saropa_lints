// ignore_for_file: depend_on_referenced_packages

/// Custom lint rules for Saropa codebase.
///
/// ## Configuration
///
/// Generate your configuration with the CLI tool:
///
/// ```bash
/// dart run saropa_lints:init --tier comprehensive
/// ```
///
/// This generates `analysis_options.yaml` with explicit rule lists.
/// See `BROKEN_TIERS.md` for why YAML-based tier config is not supported.
///
/// Available tiers: `essential` (1), `recommended` (2),
/// `professional` (3), `comprehensive` (4), `pedantic` (5).
///
/// You can also enable/disable individual rules in the generated file:
///
/// ```yaml
/// custom_lint:
///   rules:
///     - avoid_debug_print: false  # disable a rule
///     - no_magic_number: true     # enable a rule
/// ```
///
/// **IMPORTANT:** Rules must use YAML list format (with `-` prefix).
/// Map format (without `-`) is silently ignored by custom_lint!
library;

import 'dart:io' show Directory, File;

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
        RuleTier,
        RuleTimingRecord,
        RuleTimingTracker,
        ProgressTrackerData,
        SaropaLintRule,
        TestRelevance,
        ViolationRecord;
export 'package:saropa_lints/src/report/analysis_reporter.dart';
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
///
/// **Warning:** This instantiates ALL rules. Use sparingly for tooling only.
/// For normal analysis, the tier filtering uses [getRulesFromRegistry] which
/// only instantiates the rules needed for the selected tier.
List<LintRule> get allSaropaRules =>
    _ruleFactories.values.map((f) => f()).toList();

/// Cached package version resolved from pubspec.yaml at runtime.
String? _resolvedVersion;

/// Reads the saropa_lints version from pubspec.yaml via the consumer
/// project's `.dart_tool/package_config.json`. Falls back to `'unknown'`.
String get saropaLintsVersion => _resolvedVersion ??= _resolveVersion();

String _resolveVersion() {
  try {
    final configFile = File('.dart_tool/package_config.json');
    if (!configFile.existsSync()) return 'unknown';

    final config = configFile.readAsStringSync();
    final uriMatch = RegExp(
      r'"name":\s*"saropa_lints"[^}]*"rootUri":\s*"([^"]+)"',
    ).firstMatch(config);
    final rootUri = uriMatch?.group(1);
    if (rootUri == null) return 'unknown';

    // Resolve rootUri to an absolute directory path.
    final String packageDir;
    if (rootUri.startsWith('file://')) {
      packageDir = Uri.parse(rootUri).toFilePath();
    } else if (rootUri.startsWith('../')) {
      final dartToolDir = Directory('.dart_tool').absolute.path;
      packageDir = Directory('$dartToolDir/$rootUri').absolute.path;
    } else {
      return 'unknown';
    }

    final pubspec = File('$packageDir/pubspec.yaml');
    if (!pubspec.existsSync()) return 'unknown';

    final versionMatch = RegExp(r'^version:\s*(.+)$', multiLine: true)
        .firstMatch(pubspec.readAsStringSync());
    return versionMatch?.group(1)?.trim() ?? 'unknown';
  } catch (_) {
    return 'unknown';
  }
}

/// Entry point for custom_lint
PluginBase createPlugin() {
  // ignore: avoid_print
  print('[saropa_lints] createPlugin() called - version $saropaLintsVersion');
  return _SaropaLints();
}

/// All rule factories (not instances).
///
/// This list contains constructor references (`.new`), not instances.
/// Rules are only instantiated when needed via [getRulesFromRegistry].
/// This reduces memory usage from ~4GB (all rules) to ~500MB (essential tier).
final List<LintRule Function()> _allRuleFactories = <LintRule Function()>[
  // Core rules
  AlwaysFailRule.new,
  AvoidNullAssertionRule.new,
  AvoidDebugPrintRule.new,
  AvoidUnguardedDebugRule.new,
  PreferConstStringListRule.new,
  AvoidContextInInitStateDisposeRule.new,
  AvoidStoringContextRule.new,
  AvoidContextAcrossAsyncRule.new,
  AvoidContextAfterAwaitInStaticRule.new,
  AvoidContextInAsyncStaticRule.new,
  AvoidContextInStaticMethodsRule.new,
  AvoidIsarEnumFieldRule.new,
  AvoidAdjacentStringsRule.new,
  AvoidContinueRule.new,
  AvoidEmptySpreadRule.new,
  AvoidOnlyRethrowRule.new,
  NoEmptyStringRule.new,
  PreferContainsRule.new,
  PreferFirstRule.new,
  RequireDisposeRule.new,
  RequireTimerCancellationRule.new,
  NullifyAfterDisposeRule.new,
  AvoidMisnamedPaddingRule.new,
  AvoidRedundantElseRule.new,
  AvoidDuplicateMapKeysRule.new,
  AvoidNestedSwitchesRule.new,
  AvoidLocalFunctionsRule.new,
  AvoidUnnecessarySuperRule.new,
  AvoidNestedFuturesRule.new,
  AvoidOneFieldRecordsRule.new,
  AvoidNestedTryRule.new,
  AvoidMapKeysContainsRule.new,
  AvoidEmptySetStateRule.new,
  AvoidSingleChildColumnRowRule.new,
  AvoidLongParameterListRule.new,
  PreferBooleanPrefixesRule.new,
  PreferBooleanPrefixesForLocalsRule.new,
  PreferBooleanPrefixesForParamsRule.new,
  AvoidReturningCascadesRule.new,
  AvoidPositionalRecordFieldAccessRule.new,
  AvoidDeclaringCallMethodRule.new,
  AvoidUnmarkedPublicClassRule.new,
  PreferFinalClassRule.new,
  PreferInterfaceClassRule.new,
  PreferBaseClassRule.new,
  AvoidNestedStreamsAndFuturesRule.new,
  AvoidIfWithManyBranchesRule.new,
  AvoidInvertedBooleanChecksRule.new,
  AvoidNegatedConditionsRule.new,
  AvoidStreamToStringRule.new,
  AvoidStatelessWidgetInitializedFieldsRule.new,
  AvoidStateConstructorsRule.new,
  AvoidAssignmentsAsConditionsRule.new,
  AvoidConditionsWithBooleanLiteralsRule.new,
  AvoidSelfAssignmentRule.new,
  AvoidSelfCompareRule.new,
  NoBooleanLiteralCompareRule.new,
  NoEmptyBlockRule.new,
  PreferLastRule.new,
  AvoidDoubleSlashImportsRule.new,
  AvoidNestedRecordsRule.new,
  PreferCommentingAnalyzerIgnoresRule.new,
  AvoidReturningVoidRule.new,
  AvoidUnnecessaryConstructorRule.new,
  AvoidWeakCryptographicAlgorithmsRule.new,
  NoObjectDeclarationRule.new,
  PreferReturningConditionRule.new,
  PreferSimplerBooleanExpressionsRule.new,
  PreferWhenGuardOverIfRule.new,
  PreferDedicatedMediaQueryMethodRule.new,
  AvoidCascadeAfterIfNullRule.new,
  AvoidDuplicateExportsRule.new,
  NoEqualThenElseRule.new,
  AvoidGlobalStateRule.new,
  PreferImmediateReturnRule.new,
  PreferIterableOfRule.new,
  AvoidExpandedAsSpacerRule.new,
  AvoidDuplicateMixinsRule.new,
  AvoidDuplicateNamedImportsRule.new,
  AvoidThrowInCatchBlockRule.new,
  AvoidUnnecessaryConditionalsRule.new,
  PreferEnumsByNameRule.new,
  AvoidBorderAllRule.new,
  PreferConstBorderRadiusRule.new,
  AvoidRedundantAsyncRule.new,
  AvoidPassingSelfAsArgumentRule.new,
  PreferCorrectEdgeInsetsConstructorRule.new,
  PreferTextRichRule.new,
  AvoidWrappingInPaddingRule.new,
  PreferDefineHeroTagRule.new,
  AvoidNullableToStringRule.new,
  AvoidIncorrectImageOpacityRule.new,
  PreferUsingListViewRule.new,
  AvoidMissingImageAltRule.new,
  AvoidDuplicateTestAssertionsRule.new,
  MissingTestAssertionRule.new,
  AvoidAsyncCallbackInFakeAsyncRule.new,
  PreferSymbolOverKeyRule.new,
  UseSetStateSynchronouslyRule.new,
  AvoidSubstringRule.new,
  AvoidTopLevelMembersInTestsRule.new,
  AvoidUnnecessaryTypeAssertionsRule.new,
  AvoidUnnecessaryTypeCastsRule.new,
  AvoidExplicitPatternFieldNameRule.new,
  AlwaysRemoveListenerRule.new,
  AvoidGenericsShadowingRule.new,
  AvoidMissedCallsRule.new,
  AvoidMisusedSetLiteralsRule.new,
  AvoidUnrelatedTypeAssertionsRule.new,
  AvoidUnusedParametersRule.new,
  PreferCorrectTestFileNameRule.new,
  AvoidCastingToExtensionTypeRule.new,
  AvoidCollectionMethodsWithUnrelatedTypesRule.new,
  AvoidIncompleteCopyWithRule.new,
  AvoidUnnecessarySetStateRule.new,
  AvoidUnnecessaryStatefulWidgetsRule.new,
  CheckForEqualsInRenderObjectSettersRule.new,
  ConsistentUpdateRenderObjectRule.new,
  AvoidSingleFieldDestructuringRule.new,
  AvoidUnsafeCollectionMethodsRule.new,
  AvoidUnsafeWhereMethodsRule.new,
  PreferWhereOrNullRule.new,
  PreferNamedBooleanParametersRule.new,
  PreferEarlyReturnRule.new,
  PreferMutableCollectionsRule.new,
  PreferRecordOverEquatableRule.new,
  AvoidFlexibleOutsideFlexRule.new,
  ProperSuperCallsRule.new,
  AvoidNestedAssignmentsRule.new,
  AvoidUnconditionalBreakRule.new,
  AvoidUnnecessaryReturnRule.new,
  AvoidBitwiseOperatorsWithBooleansRule.new,
  AvoidCollapsibleIfRule.new,
  AvoidFunctionTypeInRecordsRule.new,
  AvoidNestedSwitchExpressionsRule.new,
  NoEqualConditionsRule.new,
  AvoidUnnecessaryNegationsRule.new,
  PreferCorrectIdentifierLengthRule.new,
  AvoidUnsafeReduceRule.new,
  PreferNamedParametersRule.new,
  AvoidRecursiveCallsRule.new,
  AvoidRecursiveToStringRule.new,
  AvoidShadowingRule.new,
  AvoidThrowObjectsWithoutToStringRule.new,
  AvoidDuplicateCascadesRule.new,
  AvoidEqualExpressionsRule.new,
  ExtendEquatableRule.new,
  ListAllEquatableFieldsRule.new,
  PreferEquatableMixinRule.new,
  AvoidMutableFieldInEquatableRule.new,
  AvoidCollectionEqualityChecksRule.new,
  AvoidDuplicateSwitchCaseConditionsRule.new,
  AvoidMixingNamedAndPositionalFieldsRule.new,
  AvoidMultiAssignmentRule.new,
  NoMagicStringRule.new,
  PreferTypeOverVarRule.new,
  AvoidMountedInSetStateRule.new,
  PreferSliverPrefixRule.new,
  AvoidConstantAssertConditionsRule.new,
  AvoidConstantSwitchesRule.new,
  AvoidUnnecessaryGetterRule.new,
  AvoidLateContextRule.new,
  AvoidUnnecessaryGestureDetectorRule.new,
  PreferWidgetPrivateMembersRule.new,
  AvoidBarrelFilesRule.new,
  AvoidBottomTypeInPatternsRule.new,
  AvoidBottomTypeInRecordsRule.new,
  AvoidExtensionsOnRecordsRule.new,
  AvoidImmediatelyInvokedFunctionsRule.new,
  AvoidLongFilesRule.new,
  AvoidLongFunctionsRule.new,
  AvoidLongRecordsRule.new,
  AvoidLongTestFilesRule.new,
  AvoidMediumFilesRule.new,
  AvoidMediumTestFilesRule.new,
  AvoidVeryLongFilesRule.new,
  AvoidVeryLongTestFilesRule.new,
  PreferSmallFilesRule.new,
  PreferSmallTestFilesRule.new,
  AvoidComplexArithmeticExpressionsRule.new,
  AvoidComplexConditionsRule.new,
  AvoidNonAsciiSymbolsRule.new,
  AvoidNonEmptyConstructorBodiesRule.new,
  AvoidRedundantPositionalFieldNameRule.new,
  AvoidReferencingDiscardedVariablesRule.new,
  AvoidUnnecessaryBlockRule.new,
  AvoidUnnecessaryCallRule.new,
  AvoidUnnecessaryContinueRule.new,
  AvoidUnnecessaryExtendsRule.new,
  AvoidInconsistentDigitSeparatorsRule.new,
  AvoidIncorrectUriRule.new,
  MaxImportsRule.new,
  PreferAdditionSubtractionAssignmentsRule.new,
  PreferCorrectErrorNameRule.new,
  PreferTrailingCommaRule.new,
  FormatCommentRule.new,
  NoEqualArgumentsRule.new,
  PreferCompoundAssignmentOperatorsRule.new,
  PreferCorrectSetterParameterNameRule.new,
  PreferDigitSeparatorsRule.new,
  PreferExplicitFunctionTypeRule.new,
  PreferNullAwareSpreadRule.new,
  PreferParenthesesWithIfNullRule.new,
  AvoidImplicitlyNullableExtensionTypesRule.new,
  AvoidKeywordsInWildcardPatternRule.new,
  AvoidNegationsInEqualityChecksRule.new,
  MatchGetterSetterFieldNamesRule.new,
  PreferWildcardPatternRule.new,
  AvoidNullableParametersWithDefaultValuesRule.new,
  AvoidUnnecessaryCollectionsRule.new,
  AvoidUnnecessaryDigitSeparatorsRule.new,
  AvoidUnnecessaryEnumArgumentsRule.new,
  PreferDescriptiveTestNameRule.new,
  PreferCorrectSwitchLengthRule.new,
  PreferCorrectTypeNameRule.new,
  PreferReturningConditionalsRule.new,
  AvoidExcessiveExpressionsRule.new,
  MapKeysOrderingRule.new,
  ArgumentsOrderingRule.new,
  MatchClassNamePatternRule.new,
  NewlineBeforeCaseRule.new,
  EnumConstantsOrderingRule.new,
  ParametersOrderingConventionRule.new,
  PreferCorrectHandlerNameRule.new,
  PreferUniqueTestNamesRule.new,
  UnnecessaryTrailingCommaRule.new,
  AvoidRedundantPragmaInlineRule.new,
  AvoidUnknownPragmaRule.new,
  NewlineBeforeMethodRule.new,
  PreferExplicitParameterNamesRule.new,
  PreferPrefixedGlobalConstantsRule.new,
  PreferPrivateExtensionTypeFieldRule.new,
  PreferReturningShorthandsRule.new,
  RecordFieldsOrderingRule.new,
  PreferPatternDestructuringRule.new,
  MatchLibFolderStructureRule.new,
  MoveRecordsToTypedefsRule.new,
  NewlineBeforeConstructorRule.new,
  PatternFieldsOrderingRule.new,
  PreferBothInliningAnnotationsRule.new,
  PreferCommentingFutureDelayedRule.new,
  PreferSimplerPatternsNullCheckRule.new,
  PreferSortedParametersRule.new,
  PreferVisibleForTestingOnMembersRule.new,
  MatchPositionalFieldNamesOnAssignmentRule.new,
  MissingUseResultAnnotationRule.new,
  PreferAssigningAwaitExpressionsRule.new,
  PreferCorrectFutureReturnTypeRule.new,
  PreferCorrectStreamReturnTypeRule.new,
  PreferExtractingFunctionCallbacksRule.new,
  PreferNamedImportsRule.new,
  PreferNullAwareElementsRule.new,
  PreferTestStructureRule.new,
  TagNameRule.new,
  AvoidNestedShorthandsRule.new,
  AvoidGetterPrefixRule.new,
  AvoidEmptyTestGroupsRule.new,
  AvoidEnumValuesByIndexRule.new,
  AvoidUnnecessaryLengthCheckRule.new,
  AvoidUnnecessaryCompareToRule.new,
  AvoidFutureIgnoreRule.new,
  AvoidFutureToStringRule.new,
  PreferCorrectCallbackFieldNameRule.new,
  AvoidNullableInterpolationRule.new,
  AvoidNonFinalExceptionClassFieldsRule.new,
  AvoidUnnecessaryEnumPrefixRule.new,
  AvoidUnassignedStreamSubscriptionsRule.new,
  PreferExpectLaterRule.new,
  PreferPublicExceptionClassesRule.new,
  PreferSpecifyingFutureValueTypeRule.new,
  PreferDeclaringConstConstructorRule.new,
  AvoidUnnecessaryIfRule.new,

  // Noisy rules - disabled by default but available
  AvoidCommentedOutCodeRule.new,
  AvoidDynamicRule.new,
  AvoidLateKeywordRule.new,
  AvoidNestedConditionalExpressionsRule.new,
  AvoidPassingAsyncWhenSyncExpectedRule.new,
  BinaryExpressionOperandOrderRule.new,
  DoubleLiteralFormatRule.new,
  MemberOrderingRule.new,
  NewlineBeforeReturnRule.new,
  NoMagicNumberRule.new,
  PreferAsyncAwaitRule.new,
  PreferConditionalExpressionsRule.new,
  PreferMatchFileNameRule.new,
  PreferMovingToVariableRule.new,
  PreferStaticClassRule.new,
  AvoidReturningWidgetsRule.new,
  AvoidShrinkWrapInListsRule.new,
  PreferExtractingCallbacksRule.new,
  PreferSingleWidgetPerFileRule.new,

  // Collection rules
  PreferAddAllRule.new,
  AvoidDuplicateNumberElementsRule.new,
  AvoidDuplicateStringElementsRule.new,
  AvoidDuplicateObjectElementsRule.new,
  PreferReturnAwaitRule.new,
  PreferSetForLookupRule.new,

  // Code quality rules
  AvoidUnnecessaryLocalVariableRule.new,
  AvoidUnnecessaryReassignmentRule.new,
  PreferStaticMethodRule.new,
  PreferAbstractFinalStaticClassRule.new,
  AvoidHardcodedColorsRule.new,

  // Flutter widget rules
  AvoidDeeplyNestedWidgetsRule.new,
  RequireAnimationDisposalRule.new,
  AvoidUncontrolledTextFieldRule.new,
  AvoidHardcodedAssetPathsRule.new,
  AvoidPrintInProductionRule.new,
  AvoidCatchingGenericExceptionRule.new,
  AvoidServiceLocatorOveruseRule.new,
  PreferUtcDateTimesRule.new,
  AvoidRegexInLoopRule.new,
  PreferGetterOverMethodRule.new,
  PreferNamedExtensionsRule.new,
  PreferTypedefForCallbacksRule.new,
  PreferEnhancedEnumsRule.new,
  PreferWildcardForUnusedParamRule.new,
  AvoidUnusedCallbackParametersRule.new,
  PreferConstWidgetsInListsRule.new,
  AvoidScaffoldMessengerAfterAwaitRule.new,
  AvoidBuildContextInProvidersRule.new,
  PreferSemanticWidgetNamesRule.new,
  AvoidTextScaleFactorRule.new,
  PreferWidgetStateMixinRule.new,
  AvoidImageWithoutCacheRule.new,
  PreferSplitWidgetConstRule.new,
  AvoidNavigatorPushWithoutRouteNameRule.new,
  AvoidDuplicateWidgetKeysRule.new,
  PreferSafeAreaConsumerRule.new,
  AvoidUnrestrictedTextFieldLengthRule.new,
  PreferScaffoldMessengerMaybeOfRule.new,
  AvoidFormWithoutKeyRule.new,

  // Async rules
  AvoidUnusedGenericsRule.new,
  PreferTrailingUnderscoreForUnusedRule.new,
  AvoidUnnecessaryFuturesRule.new,
  AvoidThrowInFinallyRule.new,
  AvoidUnnecessaryNullableReturnTypeRule.new,
  PreferAsyncCallbackRule.new,
  PreferFutureVoidFunctionOverAsyncCallbackRule.new,

  // Performance rules
  AvoidListViewWithoutItemExtentRule.new,
  AvoidMediaQueryInBuildRule.new,
  PreferSliverListDelegateRule.new,
  AvoidLayoutBuilderMisuseRule.new,
  AvoidRepaintBoundaryMisuseRule.new,
  AvoidSingleChildScrollViewWithColumnRule.new,
  PreferCachedNetworkImageRule.new,
  AvoidGestureDetectorInScrollViewRule.new,
  AvoidStatefulWidgetInListRule.new,
  PreferOpacityWidgetRule.new,

  // Additional code quality rules
  AvoidAlwaysNullParametersRule.new,
  AvoidAssigningToStaticFieldRule.new,
  AvoidAsyncCallInSyncFunctionRule.new,
  AvoidComplexLoopConditionsRule.new,
  AvoidConstantConditionsRule.new,
  AvoidContradictoryExpressionsRule.new,
  AvoidIdenticalExceptionHandlingBlocksRule.new,
  AvoidLateFinalReassignmentRule.new,
  AvoidMissingCompleterStackTraceRule.new,
  AvoidMissingEnumConstantInMapRule.new,
  AvoidParameterReassignmentRule.new,
  AvoidParameterMutationRule.new,
  AvoidSimilarNamesRule.new,
  AvoidUnnecessaryNullableParametersRule.new,
  FunctionAlwaysReturnsNullRule.new,
  AvoidAccessingCollectionsByConstantIndexRule.new,
  AvoidDefaultToStringRule.new,
  AvoidDuplicateConstantValuesRule.new,
  AvoidDuplicateInitializersRule.new,
  AvoidUnnecessaryOverridesRule.new,
  AvoidUnnecessaryStatementsRule.new,
  AvoidUnusedAssignmentRule.new,
  AvoidUnusedInstancesRule.new,
  AvoidUnusedAfterNullCheckRule.new,
  AvoidWildcardCasesWithEnumsRule.new,
  FunctionAlwaysReturnsSameValueRule.new,
  NoEqualNestedConditionsRule.new,
  NoEqualSwitchCaseRule.new,
  PreferAnyOrEveryRule.new,
  PreferForInRule.new,
  AvoidDuplicatePatternsRule.new,
  AvoidNestedExtensionTypesRule.new,
  AvoidSlowCollectionMethodsRule.new,
  AvoidUnassignedFieldsRule.new,
  AvoidUnassignedLateFieldsRule.new,
  AvoidUnnecessaryLateFieldsRule.new,
  AvoidUnnecessaryNullableFieldsRule.new,
  AvoidUnnecessaryPatternsRule.new,
  AvoidWildcardCasesWithSealedClassesRule.new,
  NoEqualSwitchExpressionCasesRule.new,
  PreferBytesBuilderRule.new,
  PreferPushingConditionalExpressionsRule.new,
  PreferShorthandsWithConstructorsRule.new,
  PreferShorthandsWithEnumsRule.new,
  PreferShorthandsWithStaticFieldsRule.new,

  // Medium complexity rules
  PassCorrectAcceptedTypeRule.new,
  PassOptionalArgumentRule.new,
  PreferSingleDeclarationPerFileRule.new,
  PreferSwitchExpressionRule.new,
  PreferSwitchWithEnumsRule.new,
  PreferSwitchWithSealedClassesRule.new,
  PreferTestMatchersRule.new,
  PreferUnwrappingFutureOrRule.new,

  // Hard complexity rules
  AvoidInferrableTypeArgumentsRule.new,
  AvoidPassingDefaultValuesRule.new,
  AvoidShadowedExtensionMethodsRule.new,
  AvoidUnnecessaryLocalLateRule.new,
  MatchBaseClassDefaultValueRule.new,
  MoveVariableCloserToUsageRule.new,
  MoveVariableOutsideIterationRule.new,
  PreferOverridingParentEqualityRule.new,
  PreferSpecificCasesFirstRule.new,
  UseExistingDestructuringRule.new,
  UseExistingVariableRule.new,

  // Flutter-specific rules
  AvoidInheritedWidgetInInitStateRule.new,
  AvoidRecursiveWidgetCallsRule.new,
  AvoidUndisposedInstancesRule.new,
  AvoidUnnecessaryOverridesInStateRule.new,
  DisposeFieldsRule.new,
  PassExistingFutureToFutureBuilderRule.new,
  PassExistingStreamToStreamBuilderRule.new,
  AvoidEmptyTextWidgetsRule.new,
  AvoidFontWeightAsNumberRule.new,
  PreferSizedBoxForWhitespaceRule.new,
  PreferSizedBoxSquareRule.new,
  PreferCenterOverAlignRule.new,
  PreferAlignOverContainerRule.new,
  PreferPaddingOverContainerRule.new,
  PreferConstrainedBoxOverContainerRule.new,
  PreferTransformOverContainerRule.new,
  PreferActionButtonTooltipRule.new,
  PreferVoidCallbackRule.new,
  AvoidNestedScaffoldsRule.new,
  AvoidMultipleMaterialAppsRule.new,
  AvoidRawKeyboardListenerRule.new,
  AvoidImageRepeatRule.new,
  AvoidIconSizeOverrideRule.new,
  PreferInkwellOverGestureRule.new,
  AvoidFittedBoxForTextRule.new,
  PreferListViewBuilderRule.new,
  AvoidOpacityAnimationRule.new,
  AvoidSizedBoxExpandRule.new,
  PreferSelectableTextRule.new,
  PreferSpacingOverSizedBoxRule.new,
  AvoidMaterial2FallbackRule.new,
  PreferOverlayPortalRule.new,
  PreferCarouselViewRule.new,
  PreferSearchAnchorRule.new,
  PreferTapRegionForDismissRule.new,

  // Accessibility rules (NEW)
  AvoidIconButtonsWithoutTooltipRule.new,
  AvoidSmallTouchTargetsRule.new,
  RequireExcludeSemanticsJustificationRule.new,
  AvoidColorOnlyIndicatorsRule.new,
  AvoidGestureOnlyInteractionsRule.new,
  RequireSemanticsLabelRule.new,
  AvoidMergedSemanticsHidingInfoRule.new,
  RequireLiveRegionRule.new,
  RequireHeadingSemanticsRule.new,
  AvoidImageButtonsWithoutTooltipRule.new,

  // Security rules (NEW)
  AvoidLoggingSensitiveDataRule.new,
  RequireSecureStorageRule.new,
  AvoidHardcodedCredentialsRule.new,
  RequireInputSanitizationRule.new,
  AvoidWebViewJavaScriptEnabledRule.new,
  RequireBiometricFallbackRule.new,
  AvoidEvalLikePatternsRule.new,
  AvoidDynamicCodeLoadingRule.new,
  AvoidUnverifiedNativeLibraryRule.new,
  AvoidHardcodedSigningConfigRule.new,
  RequireCertificatePinningRule.new,
  AvoidTokenInUrlRule.new,
  AvoidGenericKeyInUrlRule.new,
  AvoidClipboardSensitiveRule.new,
  AvoidStoringPasswordsRule.new,

  // Performance rules (NEW)
  RequireKeysInAnimatedListsRule.new,
  AvoidExpensiveBuildRule.new,
  // PreferConstChildWidgetsRule.new,
  AvoidSynchronousFileIoRule.new,
  PreferComputeForHeavyWorkRule.new,
  AvoidObjectCreationInHotLoopsRule.new,
  PreferCachedGetterRule.new,
  AvoidExcessiveWidgetDepthRule.new,
  RequireItemExtentForLargeListsRule.new,
  RequireImageCacheDimensionsRule.new,
  PreferImagePrecacheRule.new,
  AvoidControllerInBuildRule.new,
  AvoidSetStateInBuildRule.new,
  AvoidStringConcatenationLoopRule.new,
  AvoidLargeListCopyRule.new,

  // State management rules (NEW)
  RequireNotifyListenersRule.new,
  RequireStreamControllerDisposeRule.new,
  RequireValueNotifierDisposeRule.new,
  RequireMountedCheckRule.new,
  AvoidWatchInCallbacksRule.new,
  AvoidBlocEventInConstructorRule.new,
  RequireUpdateShouldNotifyRule.new,
  AvoidGlobalRiverpodProvidersRule.new,
  AvoidStatefulWithoutStateRule.new,
  AvoidGlobalKeyInBuildRule.new,

  // Error handling rules (NEW)
  AvoidSwallowingExceptionsRule.new,
  AvoidLosingStackTraceRule.new,
  AvoidPrintErrorRule.new,
  // RequireFutureErrorHandlingRule merged into AvoidUncaughtFutureErrorsRule
  AvoidGenericExceptionsRule.new,
  RequireErrorContextRule.new,
  PreferResultPatternRule.new,
  RequireAsyncErrorDocumentationRule.new,
  RequireErrorBoundaryRule.new,
  RequireErrorLoggingRule.new,

  // Architecture rules (NEW)
  AvoidDirectDataAccessInUiRule.new,
  AvoidBusinessLogicInUiRule.new,
  AvoidCircularDependenciesRule.new,
  AvoidGodClassRule.new,
  AvoidUiInDomainLayerRule.new,
  AvoidCrossFeatureDependenciesRule.new,
  AvoidSingletonPatternRule.new,

  // Documentation rules (NEW)
  RequirePublicApiDocumentationRule.new,
  AvoidMisleadingDocumentationRule.new,
  RequireDeprecationMessageRule.new,
  RequireComplexLogicCommentsRule.new,
  RequireParameterDocumentationRule.new,
  RequireReturnDocumentationRule.new,
  RequireExceptionDocumentationRule.new,
  RequireExampleInDocumentationRule.new,
  VerifyDocumentedParametersExistRule.new,

  // NOTE: always_fail is intentionally NOT here - it's a test hook only best practices rules (NEW)
  RequireTestAssertionsRule.new,
  AvoidVagueTestDescriptionsRule.new,
  AvoidRealNetworkCallsInTestsRule.new,
  AvoidHardcodedTestDelaysRule.new,
  RequireTestSetupTeardownRule.new,
  RequirePumpAfterInteractionRule.new,
  AvoidProductionConfigInTestsRule.new,

  // Internationalization rules (NEW)
  AvoidHardcodedStringsInUiRule.new,
  RequireLocaleAwareFormattingRule.new,
  RequireDirectionalWidgetsRule.new,
  RequirePluralHandlingRule.new,
  AvoidHardcodedLocaleRule.new,
  AvoidStringConcatenationInUiRule.new,
  AvoidTextInImagesRule.new,
  AvoidHardcodedAppNameRule.new,
  RequireIntlDateFormatLocaleRule.new,
  RequireNumberFormatLocaleRule.new,
  AvoidManualDateFormattingRule.new,
  RequireIntlCurrencyFormatRule.new,

  // API & Network rules (NEW)
  RequireHttpStatusCheckRule.new,
  // RequireApiTimeoutRule merged into RequireRequestTimeoutRule
  AvoidHardcodedApiUrlsRule.new,
  RequireRetryLogicRule.new,
  RequireTypedApiResponseRule.new,
  RequireConnectivityCheckRule.new,
  RequireApiErrorMappingRule.new,

  // Dependency Injection rules (NEW)
  AvoidServiceLocatorInWidgetsRule.new,
  AvoidTooManyDependenciesRule.new,
  AvoidInternalDependencyCreationRule.new,
  PreferAbstractDependenciesRule.new,
  AvoidSingletonForScopedDependenciesRule.new,
  AvoidCircularDiDependenciesRule.new,
  PreferNullObjectPatternRule.new,
  RequireTypedDiRegistrationRule.new,
  AvoidFunctionsInRegisterSingletonRule.new,

  // Memory Management rules (NEW)
  AvoidLargeObjectsInStateRule.new,
  RequireImageDisposalRule.new,
  AvoidCapturingThisInCallbacksRule.new,
  RequireCacheEvictionPolicyRule.new,
  PreferWeakReferencesForCacheRule.new,
  AvoidExpandoCircularReferencesRule.new,
  AvoidLargeIsolateCommunicationRule.new,

  // Type Safety rules (NEW)
  AvoidUnsafeCastRule.new,
  PreferConstrainedGenericsRule.new,
  RequireCovariantDocumentationRule.new,
  RequireSafeJsonParsingRule.new,
  RequireNullSafeExtensionsRule.new,
  PreferSpecificNumericTypesRule.new,
  RequireFutureOrDocumentationRule.new,

  // Resource Management rules (NEW)
  RequireFileCloseInFinallyRule.new,
  RequireHiveDatabaseCloseRule.new,
  RequireHttpClientCloseRule.new,
  RequireNativeResourceCleanupRule.new,
  RequireWebSocketCloseRule.new,
  RequirePlatformChannelCleanupRule.new,
  RequireIsolateKillRule.new,

  // New formatting rules
  AvoidDigitSeparatorsRule.new,
  FormatCommentFormattingRule.new,
  MemberOrderingFormattingRule.new,
  ParametersOrderingConventionRule.new,

  // New widget rules
  RequireTextOverflowHandlingRule.new,
  RequireImageErrorBuilderRule.new,
  RequireImageDimensionsRule.new,
  RequirePlaceholderForNetworkRule.new,
  RequireScrollControllerDisposeRule.new,
  RequireFocusNodeDisposeRule.new,
  PreferTextThemeRule.new,
  AvoidNestedScrollablesRule.new,

  // New widget rules from roadmap (batch 1)
  AvoidHardcodedLayoutValuesRule.new,
  PreferIgnorePointerRule.new,
  AvoidGestureWithoutBehaviorRule.new,
  AvoidDoubleTapSubmitRule.new,
  PreferCursorForButtonsRule.new,
  RequireHoverStatesRule.new,
  RequireButtonLoadingStateRule.new,
  AvoidHardcodedTextStylesRule.new,
  PreferPageStorageKeyRule.new,
  RequireRefreshIndicatorRule.new,

  // New widget rules from roadmap (batch 2 - Very Easy)
  RequireScrollPhysicsRule.new,
  PreferSliverListRule.new,
  PreferKeepAliveRule.new,
  RequireDefaultTextStyleRule.new,
  PreferWrapOverOverflowRule.new,
  PreferAssetImageForLocalRule.new,
  PreferFitCoverForBackgroundRule.new,
  RequireDisabledStateRule.new,
  RequireDragFeedbackRule.new,

  // New widget rules from roadmap (batch 2 - Easy)
  AvoidGestureConflictRule.new,
  AvoidLargeImagesInMemoryRule.new,
  AvoidLayoutBuilderInScrollableRule.new,
  PreferIntrinsicDimensionsRule.new,
  PreferActionsAndShortcutsRule.new,
  RequireLongPressCallbackRule.new,
  AvoidFindChildInBuildRule.new,
  AvoidUnboundedConstraintsRule.new,

  // New test rules from roadmap
  AvoidTestSleepRule.new,
  AvoidFindByTextRule.new,
  RequireTestKeysRule.new,

  // New test rule
  PreferPumpAndSettleRule.new,

  // Testing best practices rules (Section 5.31)
  PreferTestFindByKeyRule.new,
  PreferSetupTeardownRule.new,
  RequireTestDescriptionConventionRule.new,
  PreferBlocTestPackageRule.new,
  PreferMockVerifyRule.new,

  // New state management rules
  RequireBlocCloseRule.new,
  PreferConsumerWidgetRule.new,
  RequireAutoDisposeRule.new,

  // New security rule
  AvoidDynamicSqlRule.new,

  // Stylistic / Opinionated rules (not in any tier by default)
  PreferRelativeImportsRule.new,
  PreferOneWidgetPerFileRule.new,
  PreferArrowFunctionsRule.new,
  PreferAllNamedParametersRule.new,
  PreferTrailingCommaAlwaysRule.new,
  PreferPrivateUnderscorePrefixRule.new,
  PreferWidgetMethodsOverClassesRule.new,
  PreferExplicitTypesRule.new,
  PreferClassOverRecordReturnRule.new,
  PreferInlineCallbacksRule.new,
  PreferSingleQuotesRule.new,
  PreferTodoFormatRule.new,
  PreferFixmeFormatRule.new,
  PreferSentenceCaseCommentsRule.new,
  PreferPeriodAfterDocRule.new,
  PreferScreamingCaseConstantsRule.new,
  PreferDescriptiveBoolNamesRule.new,
  PreferDescriptiveBoolNamesStrictRule.new,
  PreferSnakeCaseFilesRule.new,
  AvoidSmallTextRule.new,
  PreferDocCommentsOverRegularRule.new,
  PreferStraightApostropheRule.new,
  PreferDocCurlyApostropheRule.new,
  PreferDocStraightApostropheRule.new,
  PreferCurlyApostropheRule.new,

  // =========================================================================
  // NEW STYLISTIC RULES v2.5.0 (76+ opinionated rules with opposites)
  // =========================================================================

  // Widget & UI stylistic rules (stylistic_widget_rules.dart)
  PreferSizedBoxOverContainerRule.new,
  PreferContainerOverSizedBoxRule.new,
  PreferTextRichOverRichTextRule.new,
  PreferRichTextOverTextRichRule.new,
  PreferEdgeInsetsSymmetricRule.new,
  PreferEdgeInsetsOnlyRule.new,
  PreferBorderRadiusCircularRule.new,
  PreferExpandedOverFlexibleRule.new,
  PreferFlexibleOverExpandedRule.new,
  PreferMaterialThemeColorsRule.new,
  PreferExplicitColorsRule.new,
  PreferClipRSuperellipseRule.new,
  PreferClipRSuperellipseClipperRule.new,

  // Null handling & collection stylistic rules (stylistic_null_collection_rules.dart)
  PreferNullAwareAssignmentRule.new,
  PreferExplicitNullAssignmentRule.new,
  PreferIfNullOverTernaryRule.new,
  PreferTernaryOverIfNullRule.new,
  PreferLateOverNullableRule.new,
  PreferNullableOverLateRule.new,
  PreferSpreadOverAddAllRule.new,
  PreferAddAllOverSpreadRule.new,
  PreferCollectionIfOverTernaryRule.new,
  PreferTernaryOverCollectionIfRule.new,
  PreferWhereTypeOverWhereIsRule.new,
  PreferMapEntriesIterationRule.new,
  PreferKeysIterationRule.new,

  // Control flow stylistic rules (stylistic_control_flow_rules.dart)
  PreferSingleExitPointRule.new,
  PreferGuardClausesRule.new,
  PreferPositiveConditionsFirstRule.new,
  PreferPositiveConditionsRule.new,
  PreferSwitchStatementRule.new,
  PreferCascadeOverChainedRule.new,
  PreferChainedOverCascadeRule.new,
  PreferExhaustiveEnumsRule.new,
  PreferDefaultEnumCaseRule.new,
  PreferAwaitOverThenRule.new,
  PreferThenOverAwaitRule.new,
  PreferSyncOverAsyncWhereSimpleRule.new,

  // Whitespace & constructor stylistic rules (stylistic_whitespace_constructor_rules.dart)
  // PreferBlankLineBeforeReturnRule(), // Not defined
  PreferNoBlankLineBeforeReturnRule.new,
  PreferBlankLineAfterDeclarationsRule.new,
  PreferCompactDeclarationsRule.new,
  PreferBlankLinesBetweenMembersRule.new,
  PreferCompactClassMembersRule.new,
  PreferNoBlankLineInsideBlocksRule.new,
  PreferSingleBlankLineMaxRule.new,
  PreferSuperParametersRule.new,
  PreferInitializingFormalsRule.new,
  PreferConstructorBodyAssignmentRule.new,
  PreferFactoryForValidationRule.new,
  PreferConstructorAssertionRule.new,
  PreferRequiredBeforeOptionalRule.new,
  PreferGroupedByPurposeRule.new,
  PreferRethrowOverThrowERule.new,

  // Error handling & testing stylistic rules (stylistic_error_testing_rules.dart)
  PreferSpecificExceptionsRule.new,
  PreferGenericExceptionRule.new,
  PreferExceptionSuffixRule.new,
  PreferErrorSuffixRule.new,
  PreferOnOverCatchRule.new,
  PreferCatchOverOnRule.new,
  PreferGivenWhenThenCommentsRule.new,
  PreferSelfDocumentingTestsRule.new,
  PreferExpectOverAssertInTestsRule.new,
  PreferSingleExpectationPerTestRule.new,
  PreferGroupedExpectationsRule.new,
  PreferTestNameShouldWhenRule.new,
  PreferTestNameDescriptiveRule.new,

  // Additional stylistic rules (stylistic_additional_rules.dart)
  PreferInterpolationOverConcatenationRule.new,
  PreferConcatenationOverInterpolationRule.new,
  PreferDoubleQuotesRule.new,
  PreferAbsoluteImportsRule.new,
  PreferGroupedImportsRule.new,
  PreferFlatImportsRule.new,
  PreferFieldsBeforeMethodsRule.new,
  PreferMethodsBeforeFieldsRule.new,
  PreferStaticMembersFirstRule.new,
  PreferInstanceMembersFirstRule.new,
  PreferPublicMembersFirstRule.new,
  PreferPrivateMembersFirstRule.new,
  PreferVarOverExplicitTypeRule.new,
  PreferObjectOverDynamicRule.new,
  PreferDynamicOverObjectRule.new,
  PreferLowerCamelCaseConstantsRule.new,
  PreferCamelCaseMethodNamesRule.new,
  PreferDescriptiveVariableNamesRule.new,
  PreferConciseVariableNamesRule.new,
  PreferExplicitThisRule.new,
  PreferImplicitBooleanComparisonRule.new,
  PreferExplicitBooleanComparisonRule.new,

  // Testing best practices rules (batch 3)
  RequireArrangeActAssertRule.new,
  PreferMockNavigatorRule.new,
  AvoidRealTimerInWidgetTestRule.new,
  RequireMockVerificationRule.new,
  PreferMatcherOverEqualsRule.new,
  PreferTestWrapperRule.new,
  RequireScreenSizeTestsRule.new,
  AvoidStatefulTestSetupRule.new,
  PreferMockHttpRule.new,
  RequireGoldenTestRule.new,

  // Widget rules (batch 3)
  PreferFractionalSizingRule.new,
  AvoidUnconstrainedBoxMisuseRule.new,
  RequireErrorWidgetRule.new,
  PreferSliverAppBarRule.new,
  AvoidOpacityMisuseRule.new,
  PreferClipBehaviorRule.new,
  RequireScrollControllerRule.new,
  PreferPositionedDirectionalRule.new,
  RequireFormValidationRule.new,

  // High-impact rules (batch 4)
  AvoidShrinkWrapInScrollRule.new,
  AvoidDeepWidgetNestingRule.new,
  PreferSafeAreaAwareRule.new,
  AvoidRefInBuildBodyRule.new,
  RequireImmutableBlocStateRule.new,
  RequireRequestTimeoutRule.new,
  AvoidFlakyTestsRule.new,

  // New accessibility rules
  AvoidTextScaleFactorIgnoreRule.new,
  RequireImageSemanticsRule.new,
  AvoidHiddenInteractiveRule.new,

  // New animation rules
  RequireVsyncMixinRule.new,
  AvoidAnimationInBuildRule.new,
  RequireAnimationControllerDisposeRule.new,
  RequireHeroTagUniquenessRule.new,
  AvoidLayoutPassesRule.new,

  // New forms rules
  PreferAutovalidateOnInteractionRule.new,
  RequireKeyboardTypeRule.new,
  RequireTextOverflowInRowRule.new,
  RequireSecureKeyboardRule.new,

  // New navigation rules
  RequireUnknownRouteHandlerRule.new,
  AvoidContextAfterNavigationRule.new,

  // New security/performance rules
  PreferSecureRandomRule.new,
  PreferTypedDataRule.new,
  AvoidUnnecessaryToListRule.new,

  // New Firebase/storage rules
  AvoidFirestoreUnboundedQueryRule.new,
  AvoidDatabaseInBuildRule.new,
  AvoidSecureStorageOnWebRule.new,
  IncorrectFirebaseEventNameRule.new,
  IncorrectFirebaseParameterNameRule.new,

  // New state management rules
  AvoidProviderOfInBuildRule.new,
  AvoidGetFindInBuildRule.new,
  AvoidProviderRecreateRule.new,

  AvoidHardcodedDurationRule.new,
  RequireAnimationCurveRule.new,
  AvoidFixedDimensionsRule.new,
  AvoidPrefsForLargeDataRule.new,
  RequireOfflineIndicatorRule.new,

  PreferCoarseLocationRule.new,
  RequireCameraDisposeRule.new,
  RequireImageCompressionRule.new,
  RequireThemeColorFromSchemeRule.new,
  PreferColorSchemeFromSeedRule.new,

  PreferRichTextForComplexRule.new,
  RequireErrorMessageContextRule.new,
  PreferImplicitAnimationsRule.new,
  RequireStaggeredAnimationDelaysRule.new,
  PreferCubitForSimpleRule.new,

  RequireBlocObserverRule.new,
  RequireRouteTransitionConsistencyRule.new,
  RequireTestGroupsRule.new,

  AvoidRefInDisposeRule.new,
  RequireProviderScopeRule.new,
  PreferSelectForPartialRule.new,
  AvoidProviderInWidgetRule.new,
  PreferFamilyForParamsRule.new,

  // Riverpod rules (from roadmap)
  AvoidRefReadInsideBuildRule.new,
  AvoidRefWatchOutsideBuildRule.new,
  AvoidRefInsideStateDisposeRule.new,
  UseRefReadSynchronouslyRule.new,
  UseRefAndStateSynchronouslyRule.new,
  AvoidAssigningNotifiersRule.new,
  AvoidNotifierConstructorsRule.new,
  PreferImmutableProviderArgumentsRule.new,

  AvoidScrollListenerInBuildRule.new,
  PreferValueListenableBuilderRule.new,
  AvoidGlobalKeyMisuseRule.new,
  RequireRepaintBoundaryRule.new,
  AvoidTextSpanInBuildRule.new,

  AvoidTestCouplingRule.new,
  RequireTestIsolationRule.new,
  AvoidRealDependenciesInTestsRule.new,
  RequireScrollTestsRule.new,
  RequireTextInputTestsRule.new,

  AvoidNavigatorPushUnnamedRule.new,
  RequireRouteGuardsRule.new,
  AvoidCircularRedirectsRule.new,
  AvoidPopWithoutResultRule.new,
  PreferShellRouteForPersistentUiRule.new,

  RequireAuthCheckRule.new,
  RequireTokenRefreshRule.new,
  AvoidJwtDecodeClientRule.new,
  RequireLogoutCleanupRule.new,
  AvoidAuthInQueryParamsRule.new,

  AvoidBlocEventMutationRule.new,
  PreferMultiBlocProviderRule.new,
  AvoidInstantiatingInBlocValueProviderRule.new,
  AvoidExistingInstancesInBlocProviderRule.new,
  PreferCorrectBlocProviderRule.new,
  PreferMultiProviderRule.new,
  AvoidInstantiatingInValueProviderRule.new,
  DisposeProvidersRule.new,
  // ProperGetxSuperCallsRule(), // Hidden in all_rules.dart
  // AlwaysRemoveGetxListenerRule(), // Hidden in all_rules.dart
  AvoidHooksOutsideBuildRule.new,
  AvoidConditionalHooksRule.new,
  AvoidUnnecessaryHookWidgetsRule.new,
  PreferCopyWithForStateRule.new,
  AvoidBlocListenInBuildRule.new,
  RequireInitialStateRule.new,
  RequireErrorStateRule.new,
  AvoidBlocInBlocRule.new,
  PreferSealedEventsRule.new,
  CheckIsNotClosedAfterAsyncGapRule.new,
  AvoidDuplicateBlocEventHandlersRule.new,
  PreferImmutableBlocEventsRule.new,
  PreferImmutableBlocStateRule.new,
  PreferSealedBlocEventsRule.new,
  PreferSealedBlocStateRule.new,

  PreferConstWidgetsRule.new,
  AvoidExpensiveComputationInBuildRule.new,
  AvoidWidgetCreationInLoopRule.new,
  AvoidCallingOfInBuildRule.new,
  RequireImageCacheManagementRule.new,
  AvoidMemoryIntensiveOperationsRule.new,
  AvoidClosureMemoryLeakRule.new,
  PreferStaticConstWidgetsRule.new,
  RequireDisposePatternRule.new,

  RequireFormKeyRule.new,
  AvoidValidationInBuildRule.new,
  RequireSubmitButtonStateRule.new,
  AvoidFormWithoutUnfocusRule.new,
  RequireFormRestorationRule.new,
  AvoidClearingFormOnErrorRule.new,
  RequireFormFieldControllerRule.new,
  AvoidFormInAlertDialogRule.new,
  RequireFormAutoValidateModeRule.new,
  RequireAutofillHintsRule.new,
  PreferOnFieldSubmittedRule.new,

  PreferSystemThemeDefaultRule.new,
  AvoidAbsorbPointerMisuseRule.new,
  AvoidBrightnessCheckForThemeRule.new,
  RequireSafeAreaHandlingRule.new,
  PreferScalableTextRule.new,
  PreferSingleAssertionRule.new,
  AvoidFindAllRule.new,
  RequireIntegrationTestSetupRule.new,
  RequireFirebaseInitBeforeUseRule.new,

  // Security rules
  AvoidAuthStateInPrefsRule.new,
  PreferEncryptedPrefsRule.new,
  // Accessibility rules
  RequireButtonSemanticsRule.new,
  PreferExplicitSemanticsRule.new,
  AvoidHoverOnlyRule.new,
  // State management rules
  PreferRefWatchOverReadRule.new,
  AvoidChangeNotifierInWidgetRule.new,
  RequireProviderDisposeRule.new,
  // Testing rules
  AvoidHardcodedDelaysRule.new,
  // Resource management rules
  AvoidImagePickerWithoutSourceRule.new,
  // Platform-specific rules
  PreferCupertinoForIosFeelRule.new,
  PreferUrlStrategyForWebRule.new,
  RequireWindowSizeConstraintsRule.new,
  PreferKeyboardShortcutsRule.new,
  // Notification rules
  RequireNotificationChannelAndroidRule.new,
  AvoidNotificationPayloadSensitiveRule.new,

  // Widget rules
  AvoidNullableWidgetMethodsRule.new,
  // Code quality rules
  AvoidDuplicateStringLiteralsRule.new,
  AvoidDuplicateStringLiteralsPairRule.new,
  // State management rules
  AvoidSetStateInLargeStateClassRule.new,

  // Widget rules
  RequireOverflowBoxRationaleRule.new,
  AvoidUnconstrainedImagesRule.new,
  // Accessibility rules
  RequireErrorIdentificationRule.new,
  RequireMinimumContrastRule.new,
  // Testing rules
  RequireErrorCaseTestsRule.new,
  // Security rules
  RequireDeepLinkValidationRule.new,
  // Network performance rules
  PreferStreamingResponseRule.new,

  // Riverpod rules
  AvoidCircularProviderDepsRule.new,
  RequireErrorHandlingInAsyncRule.new,
  PreferNotifierOverStateRule.new,
  // GetX rules (hidden in all_rules.dart)
  // RequireGetxControllerDisposeRule(),
  // AvoidObsOutsideControllerRule(),
  // Bloc rules
  RequireBlocTransformerRule.new,
  AvoidLongEventHandlersRule.new,
  // Performance rules
  RequireListPreallocateRule.new,
  PreferBuilderForConditionalRule.new,
  RequireWidgetKeyStrategyRule.new,

  // Network performance rules (batch 5)
  PreferHttpConnectionReuseRule.new,
  AvoidRedundantRequestsRule.new,
  RequireResponseCachingRule.new,
  PreferPaginationRule.new,
  AvoidOverFetchingRule.new,
  RequireCancelTokenRule.new,

  // State management rules (batch 5)
  RequireRiverpodLintRule.new,
  RequireMultiProviderRule.new,
  AvoidNestedProvidersRule.new,

  // Testing rules (batch 5)
  PreferFakeOverMockRule.new,
  RequireEdgeCaseTestsRule.new,
  PreferTestDataBuilderRule.new,
  AvoidTestImplementationDetailsRule.new,

  // Security rules (batch 5)
  RequireDataEncryptionRule.new,
  PreferDataMaskingRule.new,
  AvoidScreenshotSensitiveRule.new,
  RequireSecurePasswordFieldRule.new,
  AvoidPathTraversalRule.new,
  PreferHtmlEscapeRule.new,

  // Database rules (batch 5)
  RequireDatabaseMigrationRule.new,
  RequireDatabaseIndexRule.new,
  PreferTransactionForBatchRule.new,
  RequireHiveDatabaseCloseRule.new,
  RequireTypeAdapterRegistrationRule.new,
  PreferLazyBoxForLargeRule.new,

  // Disposal rules (NEW)
  RequireMediaPlayerDisposeRule.new,
  RequireTabControllerDisposeRule.new,
  RequireTextEditingControllerDisposeRule.new,
  RequirePageControllerDisposeRule.new,

  // Build method anti-pattern rules (NEW)
  AvoidGradientInBuildRule.new,
  AvoidDialogInBuildRule.new,
  AvoidSnackbarInBuildRule.new,
  AvoidAnalyticsInBuildRule.new,
  AvoidJsonEncodeInBuildRule.new,
  AvoidGetItInBuildRule.new,
  AvoidCanvasInBuildRule.new,
  AvoidHardcodedFeatureFlagsRule.new,

  // Scroll and list rules (NEW)
  AvoidShrinkWrapInScrollViewRule.new,
  AvoidNestedScrollablesConflictRule.new,
  AvoidListViewChildrenForLargeListsRule.new,
  AvoidExcessiveBottomNavItemsRule.new,
  RequireTabControllerLengthSyncRule.new,
  AvoidRefreshWithoutAwaitRule.new,
  AvoidMultipleAutofocusRule.new,
  AvoidShrinkWrapExpensiveRule.new,
  PreferItemExtentRule.new,
  PreferPrototypeItemRule.new,
  RequireKeyForReorderableRule.new,
  RequireKeyForCollectionRule.new,
  RequireAddAutomaticKeepAlivesOffRule.new,

  // Cryptography rules (NEW)
  AvoidHardcodedEncryptionKeysRule.new,
  PreferSecureRandomForCryptoRule.new,
  AvoidDeprecatedCryptoAlgorithmsRule.new,
  RequireUniqueIvPerEncryptionRule.new,

  // JSON and DateTime rules (NEW)
  RequireJsonDecodeTryCatchRule.new,
  AvoidDateTimeParseUnvalidatedRule.new,
  PreferTryParseForDynamicDataRule.new,
  AvoidDoubleForMoneyRule.new,
  // AvoidSensitiveDataInLogsRule removed v4.2.3 - use AvoidSensitiveInLogsRule (alias works)
  RequireGetItResetInTestsRule.new,
  RequireWebSocketErrorHandlingRule.new,
  AvoidAutoplayAudioRule.new,

  // Accessibility rules (Plan Group C)
  RequireAvatarAltTextRule.new,
  RequireBadgeSemanticsRule.new,
  RequireBadgeCountLimitRule.new,

  // Image & Media rules (Plan Group A)
  AvoidImageRebuildOnScrollRule.new,
  RequireAvatarFallbackRule.new,
  PreferVideoLoadingPlaceholderRule.new,

  // Dialog & Snackbar rules (Plan Group D)
  RequireSnackbarDurationRule.new,
  RequireDialogBarrierDismissibleRule.new,
  RequireDialogResultHandlingRule.new,
  AvoidSnackbarQueueBuildupRule.new,

  // Form & Input rules (Plan Group E)
  RequireKeyboardActionTypeRule.new,
  RequireKeyboardDismissOnScrollRule.new,

  // Duration & DateTime rules (Plan Group F)
  PreferDurationConstantsRule.new,
  AvoidDatetimeNowInTestsRule.new,

  // UI/UX Pattern rules (Plan Groups G, J, K)
  RequireResponsiveBreakpointsRule.new,
  PreferCachedPaintObjectsRule.new,
  RequireCustomPainterShouldRepaintRule.new,
  RequireCurrencyFormattingLocaleRule.new,
  RequireNumberFormattingLocaleRule.new,
  RequireGraphqlOperationNamesRule.new,
  AvoidBadgeWithoutMeaningRule.new,
  PreferLoggerOverPrintRule.new,
  PreferItemExtentWhenKnownRule.new,
  RequireTabStatePreservationRule.new,

  // Bluetooth & Hardware rules (Plan Group H)
  AvoidBluetoothScanWithoutTimeoutRule.new,
  RequireBluetoothStateCheckRule.new,
  RequireBleDisconnectHandlingRule.new,
  RequireAudioFocusHandlingRule.new,
  RequireQrPermissionCheckRule.new,
  PreferBleMtuNegotiationRule.new,

  // QR Scanner rules (Plan Group I)
  RequireQrScanFeedbackRule.new,
  AvoidQrScannerAlwaysActiveRule.new,
  RequireQrContentValidationRule.new,

  // File & Error Handling rules (Plan Group G)
  RequireFileExistsCheckRule.new,
  RequirePdfErrorHandlingRule.new,
  RequireGraphqlErrorHandlingRule.new,
  AvoidLoadingFullPdfInMemoryRule.new,

  // GraphQL rules
  AvoidGraphqlStringQueriesRule.new,

  // Image rules (Plan Group A)
  PreferImageSizeConstraintsRule.new,

  // Lifecycle rules (Plan Group B)
  RequireLifecycleObserverRule.new,

  // Collection & Loop rules (Phase 2)
  PreferCorrectForLoopIncrementRule.new,
  AvoidUnreachableForLoopRule.new,

  // Widget Optimization rules (Phase 2)
  PreferSingleSetStateRule.new,
  PreferComputeOverIsolateRunRule.new,
  PreferForLoopInChildrenRule.new,
  PreferContainerRule.new,

  // Flame Engine rules (Phase 2)
  AvoidCreatingVectorInUpdateRule.new,
  AvoidRedundantAsyncOnLoadRule.new,

  // Bloc Naming rules (Phase 2)
  PreferBlocEventSuffixRule.new,
  PreferBlocStateSuffixRule.new,

  // Code Quality rules (Phase 2)
  PreferTypedefsForCallbacksRule.new,
  PreferRedirectingSuperclassConstructorRule.new,
  AvoidEmptyBuildWhenRule.new,
  PreferUsePrefixRule.new,

  // Provider Advanced rules (Phase 2)
  PreferImmutableSelectorValueRule.new,
  PreferProviderExtensionsRule.new,

  // Riverpod Widget rules (Phase 2)
  AvoidUnnecessaryConsumerWidgetsRule.new,
  AvoidNullableAsyncValuePatternRule.new,

  // GetX Build rules (Phase 2) - hidden in all_rules.dart
  // AvoidGetxRxInsideBuildRule(),
  // AvoidMutableRxVariablesRule(),

  // Remaining ROADMAP_NEXT rules
  DisposeProvidedInstancesRule.new,
  // DisposeGetxFieldsRule(), // Hidden in all_rules.dart
  PreferNullableProviderTypesRule.new,

  // Internationalization rules (ROADMAP_NEXT)
  PreferDateFormatRule.new,
  PreferIntlNameRule.new,
  PreferProvidingIntlDescriptionRule.new,
  PreferProvidingIntlExamplesRule.new,

  // Error handling rules (ROADMAP_NEXT)
  AvoidUncaughtFutureErrorsRule.new,

  // Type safety rules (ROADMAP_NEXT)
  PreferExplicitTypeArgumentsRule.new,

  // Image rules (roadmap_up_next)
  RequireImageLoadingPlaceholderRule.new,
  RequireMediaLoadingStateRule.new,
  RequirePdfLoadingIndicatorRule.new,
  PreferClipboardFeedbackRule.new,

  // Disposal rules (roadmap_up_next)
  RequireStreamSubscriptionCancelRule.new,

  // Async rules (roadmap_up_next)
  AvoidDialogContextAfterAsyncRule.new,
  RequireWebsocketMessageValidationRule.new,
  RequireFeatureFlagDefaultRule.new,
  PreferUtcForStorageRule.new,
  RequireLocationTimeoutRule.new,

  // Firebase/Maps rules (roadmap_up_next)
  PreferFirestoreBatchWriteRule.new,
  AvoidFirestoreInWidgetBuildRule.new,
  PreferFirebaseRemoteConfigDefaultsRule.new,
  RequireFcmTokenRefreshHandlerRule.new,
  RequireBackgroundMessageHandlerRule.new,
  AvoidMapMarkersInBuildRule.new,
  RequireMapIdleCallbackRule.new,
  PreferMarkerClusteringRule.new,

  // Accessibility rules (roadmap_up_next)
  RequireImageDescriptionRule.new,
  AvoidSemanticsExclusionRule.new,
  PreferMergeSemanticsRule.new,
  RequireFocusIndicatorRule.new,
  AvoidFlashingContentRule.new,
  PreferAdequateSpacingRule.new,
  AvoidMotionWithoutReduceRule.new,
  RequireSemanticLabelIconsRule.new,
  RequireAccessibleImagesRule.new,
  AvoidAutoPlayMediaRule.new,

  // Navigation rules (roadmap_up_next)
  RequireDeepLinkFallbackRule.new,
  AvoidDeepLinkSensitiveParamsRule.new,
  PreferTypedRouteParamsRule.new,
  RequireStepperValidationRule.new,
  RequireStepCountIndicatorRule.new,
  RequireRefreshIndicatorOnListsRule.new,

  // Animation rules (roadmap_up_next)
  PreferTweenSequenceRule.new,
  RequireAnimationStatusListenerRule.new,
  AvoidOverlappingAnimationsRule.new,
  AvoidAnimationRebuildWasteRule.new,
  PreferPhysicsSimulationRule.new,

  // Platform-specific rules (roadmap_up_next)
  AvoidPlatformChannelOnWebRule.new,
  RequireCorsHandlingRule.new,
  PreferDeferredLoadingWebRule.new,
  RequireMenuBarForDesktopRule.new,
  AvoidTouchOnlyGesturesRule.new,
  AvoidCircularImportsRule.new,
  RequireWindowCloseConfirmationRule.new,
  PreferNativeFileDialogsRule.new,

  // Test rules (roadmap_up_next)
  RequireTestCleanupRule.new,
  PreferTestVariantRule.new,
  RequireAccessibilityTestsRule.new,
  RequireAnimationTestsRule.new,

  // Part 5 - SharedPreferences Security rules
  AvoidSharedPrefsSensitiveDataRule.new,
  RequireSecureStorageForAuthRule.new,
  RequireSharedPrefsNullHandlingRule.new,
  RequireSharedPrefsKeyConstantsRule.new,

  // Part 5 - sqflite Database rules
  RequireSqfliteWhereArgsRule.new,
  RequireSqfliteTransactionRule.new,
  RequireSqfliteErrorHandlingRule.new,
  PreferSqfliteBatchRule.new,
  RequireSqfliteCloseRule.new,
  AvoidSqfliteReservedWordsRule.new,

  // Part 5 - Hive Database rules
  RequireHiveInitializationRule.new,
  RequireHiveTypeAdapterRule.new,
  RequireHiveBoxCloseRule.new,
  PreferHiveEncryptionRule.new,
  RequireHiveEncryptionKeySecureRule.new,
  AvoidHiveFieldIndexReuseRule.new,

  // Part 5 - Dio HTTP Client rules
  RequireDioTimeoutRule.new,
  RequireDioErrorHandlingRule.new,
  RequireDioInterceptorErrorHandlerRule.new,
  PreferDioCancelTokenRule.new,
  RequireDioSslPinningRule.new,
  AvoidDioFormDataLeakRule.new,

  // Part 5 - Stream/Future rules
  AvoidStreamInBuildRule.new,
  RequireStreamControllerCloseRule.new,
  AvoidMultipleStreamListenersRule.new,
  RequireStreamErrorHandlingRule.new,
  RequireFutureTimeoutRule.new,

  // Part 5 - go_router Navigation rules
  AvoidGoRouterInlineCreationRule.new,
  RequireGoRouterErrorHandlerRule.new,
  RequireGoRouterRefreshListenableRule.new,
  AvoidGoRouterStringPathsRule.new,

  // Part 5 - Riverpod rules
  RequireRiverpodErrorHandlingRule.new,
  AvoidRiverpodStateMutationRule.new,
  PreferRiverpodSelectRule.new,

  // Part 5 - cached_network_image rules
  RequireCachedImageDimensionsRule.new,
  RequireCachedImagePlaceholderRule.new,
  RequireCachedImageErrorWidgetRule.new,

  // Part 5 - Geolocator rules
  RequireGeolocatorPermissionCheckRule.new,
  RequireGeolocatorServiceEnabledRule.new,
  RequireGeolocatorStreamCancelRule.new,
  RequireGeolocatorErrorHandlingRule.new,

  // Part 6 - State Management rules
  AvoidYieldInOnEventRule.new,
  PreferConsumerOverProviderOfRule.new,
  AvoidListenInAsyncRule.new,
  // PreferGetxBuilderRule(), // Hidden in all_rules.dart
  EmitNewBlocStateInstancesRule.new,
  AvoidBlocPublicFieldsRule.new,
  AvoidBlocPublicMethodsRule.new,
  RequireAsyncValueOrderRule.new,
  RequireBlocSelectorRule.new,
  PreferSelectorRule.new,
  // RequireGetxBindingRule(), // Hidden in all_rules.dart

  // Provider dependency rules
  PreferProxyProviderRule.new,
  RequireUpdateCallbackRule.new,

  // GetX context safety rules
  AvoidGetxContextOutsideWidgetRule.new,

  // Part 6 - Theming rules
  RequireDarkModeTestingRule.new,
  AvoidElevationOpacityInDarkRule.new,
  PreferThemeExtensionsRule.new,

  // Part 6 - UI/UX rules
  PreferSkeletonOverSpinnerRule.new,
  RequireEmptyResultsStateRule.new,
  RequireSearchLoadingIndicatorRule.new,
  RequireSearchDebounceRule.new,
  RequirePaginationLoadingStateRule.new,

  // Part 6 - Lifecycle rules
  AvoidWorkInPausedStateRule.new,
  RequireResumeStateRefreshRule.new,

  // Part 6 - Security rules
  RequireUrlValidationRule.new,
  AvoidRedirectInjectionRule.new,
  AvoidExternalStorageSensitiveRule.new,
  PreferLocalAuthRule.new,

  // Part 6 - Firebase rules
  RequireCrashlyticsUserIdRule.new,
  RequireFirebaseAppCheckRule.new,
  AvoidStoringUserDataInAuthRule.new,

  // Part 6 - Collection/Performance rules
  PreferNullAwareElementsRule.new,
  PreferIterableOperationsRule.new,
  PreferInheritedWidgetCacheRule.new,
  PreferLayoutBuilderOverMediaQueryRule.new,

  // Part 6 - Flutter Widget rules
  RequireShouldRebuildRule.new,
  RequireOrientationHandlingRule.new,
  RequireWebRendererAwarenessRule.new,

  // Part 6 - Additional rules
  RequireExifHandlingRule.new,
  RequireRefreshIndicatorOnListsRule.new,
  PreferAdaptiveDialogRule.new,
  RequireSnackbarActionForUndoRule.new,
  RequireContentTypeCheckRule.new,
  AvoidWebsocketWithoutHeartbeatRule.new,
  AvoidKeyboardOverlapRule.new,
  RequireLocationTimeoutRule.new,
  PreferCameraResolutionSelectionRule.new,
  PreferAudioSessionConfigRule.new,
  PreferDotShorthandRule.new,
  AvoidTouchOnlyGesturesRule.new,
  RequireFutureWaitErrorHandlingRule.new,
  RequireStreamOnDoneRule.new,
  RequireCompleterErrorHandlingRule.new,

  // Package-specific rules (NEW)
  RequireGoogleSigninErrorHandlingRule.new,
  RequireAppleSigninNonceRule.new,
  RequireSupabaseErrorHandlingRule.new,
  AvoidSupabaseAnonKeyInCodeRule.new,
  RequireSupabaseRealtimeUnsubscribeRule.new,
  RequireWebviewSslErrorHandlingRule.new,
  AvoidWebviewFileAccessRule.new,
  RequireWorkmanagerConstraintsRule.new,
  RequireWorkmanagerResultReturnRule.new,
  RequireCalendarTimezoneHandlingRule.new,
  RequireKeyboardVisibilityDisposeRule.new,
  RequireSpeechStopOnDisposeRule.new,
  AvoidAppLinksSensitiveParamsRule.new,
  RequireEnviedObfuscationRule.new,
  AvoidOpenaiKeyInCodeRule.new,
  RequireOpenaiErrorHandlingRule.new,
  RequireSvgErrorHandlerRule.new,
  RequireGoogleFontsFallbackRule.new,
  PreferUuidV4Rule.new,

  // Disposal pattern detection rules (NEW)
  RequireBlocManualDisposeRule.new,
  RequireGetxWorkerDisposeRule.new,
  RequireGetxPermanentCleanupRule.new,
  RequireAnimationTickerDisposalRule.new,
  RequireImageStreamDisposeRule.new,
  RequireSseSubscriptionCancelRule.new,

  // Late keyword rules (NEW)
  PreferLateFinalRule.new,
  AvoidLateForNullableRule.new,

  // go_router type safety rules (NEW)
  PreferGoRouterExtraTypedRule.new,

  // Firebase Auth persistence rule (NEW)
  PreferFirebaseAuthPersistenceRule.new,

  // Geolocator battery optimization rule (NEW)
  PreferGeolocatorDistanceFilterRule.new,

  // Image picker OOM prevention (NEW)
  PreferImagePickerMaxDimensionsRule.new,

  // =========================================================================
  // NEW RULES v2.3.10
  // =========================================================================

  // Test rules
  AvoidTestPrintStatementsRule.new,
  RequireMockHttpClientRule.new,

  // Async rules
  AvoidFutureThenInAsyncRule.new,
  AvoidUnawaitedFutureRule.new,

  // Forms rules
  RequireTextInputTypeRule.new,
  PreferTextInputActionRule.new,
  RequireFormKeyInStatefulWidgetRule.new,

  // Network rules
  PreferTimeoutOnRequestsRule.new,
  PreferDioOverHttpRule.new,

  // Error handling rules
  AvoidCatchAllRule.new,
  AvoidCatchExceptionAloneRule.new,

  // State management rules
  AvoidBlocContextDependencyRule.new,
  AvoidProviderValueRebuildRule.new,

  // Lifecycle rules
  RequireDidUpdateWidgetCheckRule.new,

  // Equatable rules
  RequireEquatableCopyWithRule.new,

  // Notification rules
  AvoidNotificationSameIdRule.new,

  // Internationalization rules
  RequireIntlPluralRulesRule.new,

  // Image rules
  PreferCachedImageCacheManagerRule.new,
  RequireImageCacheDimensionsRule.new,

  // Navigation rules
  PreferUrlLauncherUriOverStringRule.new,
  AvoidGoRouterPushReplacementConfusionRule.new,

  // Widget rules
  AvoidStackWithoutPositionedRule.new,
  AvoidExpandedOutsideFlexRule.new,
  AvoidTableCellOutsideTableRule.new,
  AvoidPositionedOutsideStackRule.new,
  AvoidSpacerInWrapRule.new,
  AvoidScrollableInIntrinsicRule.new,
  RequireBaselineTextBaselineRule.new,
  AvoidUnconstrainedDialogColumnRule.new,
  AvoidUnboundedListviewInColumnRule.new,
  AvoidTextfieldInRowRule.new,
  AvoidFixedSizeInScaffoldBodyRule.new,
  PreferExpandedAtCallSiteRule.new,

  // =========================================================================
  // NEW RULES v2.3.11
  // =========================================================================

  // Test rules
  RequireTestWidgetPumpRule.new,
  RequireIntegrationTestTimeoutRule.new,

  // Hive rules
  RequireHiveFieldDefaultValueRule.new,
  RequireHiveAdapterRegistrationOrderRule.new,
  RequireHiveNestedObjectAdapterRule.new,
  AvoidHiveBoxNameCollisionRule.new,

  // Security rules
  AvoidApiKeyInCodeRule.new,
  AvoidStoringSensitiveUnencryptedRule.new,

  AvoidIgnoreTrailingCommentRule.new,

  // OWASP Coverage Gap Rules (v3.2.0)
  AvoidIgnoringSslErrorsRule.new,
  RequireHttpsOnlyRule.new,
  RequireHttpsOnlyTestRule.new,
  AvoidUnsafeDeserializationRule.new,
  AvoidUserControlledUrlsRule.new,
  RequireCatchLoggingRule.new,

  // State management rules
  AvoidRiverpodNotifierInBuildRule.new,
  RequireRiverpodAsyncValueGuardRule.new,
  AvoidBlocBusinessLogicInUiRule.new,

  // Navigation rules
  RequireUrlLauncherEncodingRule.new,
  AvoidNestedRoutesWithoutParentRule.new,

  // Equatable rules
  RequireCopyWithNullHandlingRule.new,

  // Internationalization rules
  RequireIntlArgsMatchRule.new,
  AvoidStringConcatenationForL10nRule.new,

  // Performance rules
  AvoidBlockingDatabaseUiRule.new,
  AvoidMoneyArithmeticOnDoubleRule.new,
  AvoidRebuildOnScrollRule.new,

  // Error handling rules
  AvoidExceptionInConstructorRule.new,
  RequireCacheKeyDeterminismRule.new,
  RequirePermissionPermanentDenialHandlingRule.new,

  // Dependency injection rules
  RequireGetItRegistrationOrderRule.new,
  RequireDefaultConfigRule.new,

  // Widget rules
  AvoidBuilderIndexOutOfBoundsRule.new,

  // =========================================================================
  // v2.4.0 - Apple Platform Rules (76 rules)
  // See doc/guides/apple_platform_rules.md for documentation
  // =========================================================================

  // iOS Core Rules
  PreferIosSafeAreaRule.new,
  AvoidIosHardcodedStatusBarRule.new,
  PreferIosHapticFeedbackRule.new,
  RequireIosPlatformCheckRule.new,
  AvoidIosBackgroundFetchAbuseRule.new,
  RequireAppleSignInRule.new,
  RequireIosBackgroundModeRule.new,
  AvoidIos13DeprecationsRule.new,
  AvoidIosSimulatorOnlyCodeRule.new,
  RequireIosMinimumVersionCheckRule.new,
  AvoidIosDeprecatedUikitRule.new,
  RequireIosDynamicIslandSafeZonesRule.new,
  RequireIosDeploymentTargetConsistencyRule.new,
  RequireIosSceneDelegateAwarenessRule.new,

  // App Store Review Rules
  RequireIosAppTrackingTransparencyRule.new,
  RequireIosFaceIdUsageDescriptionRule.new,
  RequireIosPhotoLibraryAddUsageRule.new,
  AvoidIosInAppBrowserForAuthRule.new,
  RequireIosAppReviewPromptTimingRule.new,
  RequireIosReviewPromptFrequencyRule.new,
  RequireIosReceiptValidationRule.new,
  RequireIosAgeRatingConsiderationRule.new,
  AvoidIosMisleadingPushNotificationsRule.new,
  RequireIosPermissionDescriptionRule.new,
  RequireIosPrivacyManifestRule.new,
  RequireHttpsForIosRule.new,

  // Security & Authentication Rules
  RequireIosKeychainAccessibilityRule.new,
  RequireIosKeychainSyncAwarenessRule.new,
  RequireIosKeychainForCredentialsRule.new,
  RequireIosCertificatePinningRule.new,
  RequireIosBiometricFallbackRule.new,
  RequireIosHealthKitAuthorizationRule.new,
  AvoidIosHardcodedBundleIdRule.new,
  AvoidIosDebugCodeInReleaseRule.new,

  // Platform Integration Rules
  RequireIosPushNotificationCapabilityRule.new,
  RequireIosBackgroundAudioCapabilityRule.new,
  RequireIosBackgroundRefreshDeclarationRule.new,
  RequireIosAppGroupCapabilityRule.new,
  RequireIosSiriIntentDefinitionRule.new,
  RequireIosWidgetExtensionCapabilityRule.new,
  RequireIosLiveActivitiesSetupRule.new,
  RequireIosCarplaySetupRule.new,
  RequireIosCallkitIntegrationRule.new,
  RequireIosNfcCapabilityCheckRule.new,
  RequireIosMethodChannelCleanupRule.new,
  AvoidIosForceUnwrapInCallbacksRule.new,
  RequireMethodChannelErrorHandlingRule.new,
  PreferIosAppIntentsFrameworkRule.new,

  // Device & Hardware Rules
  AvoidIosHardcodedDeviceModelRule.new,
  RequireIosOrientationHandlingRule.new,
  RequireIosPhotoLibraryLimitedAccessRule.new,
  AvoidIosContinuousLocationTrackingRule.new,
  RequireAppLifecycleHandlingRule.new,
  RequireIosPromotionDisplaySupportRule.new,
  RequireIosPasteboardPrivacyHandlingRule.new,
  PreferIosStoreKit2Rule.new,

  // Data & Storage Rules
  RequireIosDatabaseConflictResolutionRule.new,
  RequireIosIcloudKvstoreLimitationsRule.new,
  RequireIosShareSheetUtiDeclarationRule.new,
  RequireIosAppClipSizeLimitRule.new,
  RequireIosAtsExceptionDocumentationRule.new,
  RequireIosLocalNotificationPermissionRule.new,

  // Deep Linking Rules
  RequireUniversalLinkValidationRule.new,
  RequireIosUniversalLinksDomainMatchingRule.new,

  // macOS Platform Rules
  PreferMacosMenuBarIntegrationRule.new,
  PreferMacosKeyboardShortcutsRule.new,
  RequireMacosWindowSizeConstraintsRule.new,
  RequireMacosWindowRestorationRule.new,
  RequireMacosFileAccessIntentRule.new,
  RequireMacosHardenedRuntimeRule.new,
  RequireMacosSandboxEntitlementsRule.new,
  AvoidMacosDeprecatedSecurityApisRule.new,
  AvoidMacosCatalystUnsupportedApisRule.new,
  AvoidMacosFullDiskAccessRule.new,
  PreferCupertinoForIosRule.new,
  RequireIosAccessibilityLabelsRule.new,

  // =========================================================================
  // v2.4.0 Additional Rules - Background Processing, Notifications, Payments
  // =========================================================================

  // Background Processing Rules
  AvoidLongRunningIsolatesRule.new,
  RequireWorkmanagerForBackgroundRule.new,
  RequireNotificationForLongTasksRule.new,
  PreferBackgroundSyncRule.new,
  RequireSyncErrorRecoveryRule.new,

  // Notification Rules
  PreferDelayedPermissionPromptRule.new,
  AvoidNotificationSpamRule.new,

  // In-App Purchase Rules
  RequirePurchaseVerificationRule.new,
  RequirePurchaseRestorationRule.new,

  // iOS Platform Enhancement Rules
  AvoidIosWifiOnlyAssumptionRule.new,
  RequireIosLowPowerModeHandlingRule.new,
  RequireIosAccessibilityLargeTextRule.new,
  PreferIosContextMenuRule.new,
  RequireIosQuickNoteAwarenessRule.new,
  AvoidIosHardcodedKeyboardHeightRule.new,
  RequireIosMultitaskingSupportRule.new,
  PreferIosSpotlightIndexingRule.new,
  RequireIosDataProtectionRule.new,
  AvoidIosBatteryDrainPatternsRule.new,
  RequireIosEntitlementsRule.new,
  RequireIosLaunchStoryboardRule.new,
  RequireIosVersionCheckRule.new,
  RequireIosFocusModeAwarenessRule.new,
  PreferIosHandoffSupportRule.new,
  RequireIosVoiceoverGestureCompatibilityRule.new,

  // macOS Platform Enhancement Rules
  RequireMacosSandboxExceptionsRule.new,
  AvoidMacosHardenedRuntimeViolationsRule.new,
  RequireMacosAppTransportSecurityRule.new,
  RequireMacosNotarizationReadyRule.new,
  RequireMacosEntitlementsRule.new,

  // v2.6.0 rules (ROADMAP_NEXT implementation)
  // Code quality
  PreferReturningConditionalExpressionsRule.new,

  // Riverpod rules
  PreferRiverpodAutoDisposeRule.new,
  PreferRiverpodFamilyForParamsRule.new,

  // GetX rules
  AvoidGetxGlobalNavigationRule.new,
  RequireGetxBindingRoutesRule.new,

  // Dio rules
  RequireDioResponseTypeRule.new,
  RequireDioRetryInterceptorRule.new,
  PreferDioTransformerRule.new,

  // GoRouter rules
  PreferShellRouteSharedLayoutRule.new,
  RequireStatefulShellRouteTabsRule.new,
  RequireGoRouterFallbackRouteRule.new,

  // SQLite rules
  PreferSqfliteSingletonRule.new,
  PreferSqfliteColumnConstantsRule.new,

  // Freezed rules
  RequireFreezedJsonConverterRule.new,
  RequireFreezedLintPackageRule.new,

  // Geolocation rules
  PreferGeolocatorAccuracyAppropriateRule.new,
  PreferGeolocatorLastKnownRule.new,

  // Image picker rules
  PreferImagePickerMultiSelectionRule.new,

  // Notification rules
  RequireNotificationActionHandlingRule.new,

  // Error handling rules
  RequireFinallyCleanupRule.new,

  // DI rules
  RequireDiScopeAwarenessRule.new,

  // Equatable rules
  RequireDeepEqualityCollectionsRule.new,
  AvoidEquatableDatetimeRule.new,
  PreferUnmodifiableCollectionsRule.new,

  // Hive rules
  PreferHiveValueListenableRule.new,

  // NEW ROADMAP STAR RULES
  // Bloc/Cubit rules
  AvoidPassingBlocToBlocRule.new,
  AvoidPassingBuildContextToBlocsRule.new,
  AvoidReturningValueFromCubitMethodsRule.new,
  RequireBlocRepositoryInjectionRule.new,
  PreferBlocHydrationRule.new,

  // GetX rules
  AvoidGetxDialogSnackbarInControllerRule.new,
  RequireGetxLazyPutRule.new,

  // Hive/SharedPrefs rules
  PreferHiveLazyBoxRule.new,
  AvoidHiveBinaryStorageRule.new,
  RequireSharedPrefsPrefixRule.new,
  PreferSharedPrefsAsyncApiRule.new,
  AvoidSharedPrefsInIsolateRule.new,

  // Stream rules
  PreferStreamDistinctRule.new,
  PreferBroadcastStreamRule.new,

  // Async/Build rules
  AvoidFutureInBuildRule.new,
  RequireMountedCheckAfterAwaitRule.new,
  AvoidAsyncInBuildRule.new,
  PreferAsyncInitStateRule.new,

  // Widget lifecycle rules
  RequireWidgetsBindingCallbackRule.new,

  // Navigation rules
  PreferRouteSettingsNameRule.new,

  // Internationalization rules
  PreferNumberFormatRule.new,
  ProvideCorrectIntlArgsRule.new,

  // Package-specific rules
  AvoidFreezedForLogicClassesRule.new,

  // Disposal rules
  DisposeClassFieldsRule.new,

  // State management rules
  PreferChangeNotifierProxyProviderRule.new,

  // =========================================================================
  // NEW RULES v4.1.5 (24 new rules)
  // =========================================================================

  // Dependency Injection rules
  AvoidDiInWidgetsRule.new,
  PreferAbstractionInjectionRule.new,

  // Accessibility rules
  PreferLargeTouchTargetsRule.new,
  AvoidTimeLimitsRule.new,
  RequireDragAlternativesRule.new,

  // Flutter widget rules
  AvoidGlobalKeysInStateRule.new,
  AvoidStaticRouteConfigRule.new,

  // State management rules
  RequireFlutterRiverpodNotRiverpodRule.new,
  AvoidRiverpodNavigationRule.new,

  // Firebase rules
  RequireFirebaseErrorHandlingRule.new,
  AvoidFirebaseRealtimeInBuildRule.new,

  // Security rules
  RequireSecureStorageErrorHandlingRule.new,
  AvoidSecureStorageLargeDataRule.new,

  // Navigation rules
  AvoidNavigatorContextIssueRule.new,
  RequirePopResultTypeRule.new,
  AvoidPushReplacementMisuseRule.new,
  AvoidNestedNavigatorsMisuseRule.new,
  RequireDeepLinkTestingRule.new,

  // Internationalization rules
  AvoidStringConcatenationL10nRule.new,
  PreferIntlMessageDescriptionRule.new,
  AvoidHardcodedLocaleStringsRule.new,

  // Async rules
  RequireNetworkStatusCheckRule.new,
  AvoidSyncOnEveryChangeRule.new,
  RequirePendingChangesIndicatorRule.new,

  // =========================================================================
  // NEW RULES v4.1.6 (14 new rules)
  // =========================================================================

  // Logging rules (debug_rules.dart)
  AvoidPrintInReleaseRule.new,
  RequireStructuredLoggingRule.new,
  AvoidSensitiveInLogsRule.new,

  // Platform rules (platform_rules.dart)
  RequirePlatformCheckRule.new,
  PreferPlatformIoConditionalRule.new,
  AvoidWebOnlyDependenciesRule.new,
  PreferFoundationPlatformCheckRule.new,

  // JSON/API rules (json_datetime_rules.dart)
  RequireDateFormatSpecificationRule.new,
  PreferIso8601DatesRule.new,
  AvoidOptionalFieldCrashRule.new,
  PreferExplicitJsonKeysRule.new,

  // Configuration rules (config_rules.dart)
  AvoidHardcodedConfigRule.new,
  AvoidHardcodedConfigTestRule.new,
  AvoidMixedEnvironmentsRule.new,

  // Lifecycle rules (lifecycle_rules.dart)
  RequireLateInitializationInInitStateRule.new,

  // =========================================================================
  // NEW RULES v4.1.7 (25 new rules)
  // =========================================================================

  // State management rules (v417_state_rules.dart)
  AvoidRiverpodForNetworkOnlyRule.new,
  AvoidLargeBlocRule.new,
  AvoidOverengineeredBlocStatesRule.new,
  AvoidGetxStaticContextRule.new,
  AvoidTightCouplingWithGetxRule.new,

  // Performance rules (v417_performance_rules.dart)
  PreferElementRebuildRule.new,
  RequireIsolateForHeavyRule.new,
  AvoidFinalizerMisuseRule.new,
  AvoidJsonInMainRule.new,

  // Security rules (v417_security_rules.dart)
  AvoidSensitiveDataInClipboardRule.new,
  RequireClipboardPasteValidationRule.new,
  AvoidEncryptionKeyInMemoryRule.new,

  // Caching rules (v417_caching_rules.dart)
  RequireCacheExpirationRule.new,
  AvoidUnboundedCacheGrowthRule.new,
  RequireCacheKeyUniquenessRule.new,

  // Testing rules (v417_testing_rules.dart)
  RequireDialogTestsRule.new,
  PreferFakePlatformRule.new,
  RequireTestDocumentationRule.new,

  // Widget rules (v417_widget_rules.dart)
  PreferCustomSingleChildLayoutRule.new,
  RequireLocaleForTextRule.new,
  RequireDialogBarrierConsiderationRule.new,
  PreferFeatureFolderStructureRule.new,

  // Misc rules (v417_misc_rules.dart)
  RequireWebsocketReconnectionRule.new,
  RequireCurrencyCodeWithAmountRule.new,
  PreferLazySingletonRegistrationRule.new,

  // =========================================================================
  // v4.2.0 ROADMAP ⭐ Rules
  // =========================================================================

  // Android rules (android_rules.dart)
  RequireAndroidPermissionRequestRule.new,
  AvoidAndroidTaskAffinityDefaultRule.new,
  RequireAndroid12SplashRule.new,
  PreferPendingIntentFlagsRule.new,
  AvoidAndroidCleartextTrafficRule.new,
  RequireAndroidBackupRulesRule.new,

  // IAP rules (iap_rules.dart)
  AvoidPurchaseInSandboxProductionRule.new,
  RequireSubscriptionStatusCheckRule.new,
  RequirePriceLocalizationRule.new,

  // URL Launcher rules (url_launcher_rules.dart)
  RequireUrlLauncherCanLaunchCheckRule.new,
  AvoidUrlLauncherSimulatorTestsRule.new,
  PreferUrlLauncherFallbackRule.new,

  // Permission rules (permission_rules.dart)
  RequireLocationPermissionRationaleRule.new,
  RequireCameraPermissionCheckRule.new,
  PreferImageCroppingRule.new,

  // Connectivity rules (connectivity_rules.dart)
  RequireConnectivityErrorHandlingRule.new,

  // Geolocator rules (geolocator_rules.dart)
  RequireGeolocatorBatteryAwarenessRule.new,

  // DB yield rules (db_yield_rules.dart)
  RequireYieldAfterDbWriteRule.new,
  SuggestYieldAfterDbReadRule.new,
  AvoidReturnAwaitDbRule.new,

  // SQLite rules (sqflite_rules.dart)
  AvoidSqfliteTypeMismatchRule.new,

  // Firebase rules (firebase_rules.dart)
  RequireFirestoreIndexRule.new,

  // Notification rules (notification_rules.dart)
  PreferNotificationGroupingRule.new,
  AvoidNotificationSilentFailureRule.new,

  // Hive rules (hive_rules.dart)
  RequireHiveMigrationStrategyRule.new,

  // Async rules (async_rules.dart)
  AvoidStreamSyncEventsRule.new,
  AvoidSequentialAwaitsRule.new,

  // File handling rules (file_handling_rules.dart)
  PreferStreamingForLargeFilesRule.new,
  RequireFilePathSanitizationRule.new,

  // Error handling rules (error_handling_rules.dart)
  RequireAppStartupErrorHandlingRule.new,
  AvoidAssertInProductionRule.new,

  // Accessibility rules (accessibility_rules.dart)
  PreferFocusTraversalOrderRule.new,

  // UI/UX rules (ui_ux_rules.dart)
  AvoidLoadingFlashRule.new,

  // Performance rules (performance_rules.dart)
  AvoidAnimationInLargeListRule.new,
  PreferLazyLoadingImagesRule.new,

  // JSON/DateTime rules (json_datetime_rules.dart)
  RequireJsonSchemaValidationRule.new,
  PreferJsonSerializableRule.new,

  // Forms rules (forms_rules.dart)
  PreferRegexValidationRule.new,

  // Package-specific rules (package_specific_rules.dart)
  PreferTypedPrefsWrapperRule.new,
  PreferFreezedForDataClassesRule.new,

  // Previously unregistered rules (restored)
  AlwaysRemoveGetxListenerRule.new,
  AvoidBlocEmitAfterCloseRule.new,
  AvoidBlocStateMutationRule.new,
  AvoidCachedImageInBuildRule.new,
  AvoidCachedIsarStreamRule.new,
  AvoidDioDebugPrintProductionRule.new,
  AvoidDioWithoutBaseUrlRule.new,
  AvoidDynamicJsonAccessRule.new,
  AvoidDynamicJsonChainsRule.new,
  AvoidFreezedJsonSerializableConflictRule.new,
  AvoidGetxGlobalStateRule.new,
  AvoidGetxRxInsideBuildRule.new,
  AvoidImagePickerLargeFilesRule.new,
  AvoidIsarClearInProductionRule.new,
  AvoidIsarEmbeddedLargeObjectsRule.new,
  AvoidIsarFloatEqualityQueriesRule.new,
  AvoidIsarSchemaBreakingChangesRule.new,
  AvoidIsarStringContainsWithoutIndexRule.new,
  AvoidIsarTransactionNestingRule.new,
  AvoidIsarWebLimitationsRule.new,
  AvoidLateWithoutGuaranteeRule.new,
  AvoidMutableRxVariablesRule.new,
  AvoidNavigationInBuildRule.new,
  AvoidNestedTryStatementsRule.new,
  AvoidNonNullAssertionRule.new,
  AvoidNotEncodableInToJsonRule.new,
  AvoidObsOutsideControllerRule.new,
  AvoidProviderInInitStateRule.new,
  AvoidSetStateInDisposeRule.new,
  AvoidSqfliteReadAllColumnsRule.new,
  AvoidStaticStateRule.new,
  AvoidStreamSubscriptionInFieldRule.new,
  AvoidTypeCastsRule.new,
  AvoidUnrelatedTypeCastsRule.new,
  AvoidUnremovableCallbacksInListenersRule.new,
  AvoidUnsafeSetStateRule.new,
  AvoidWebViewInsecureContentRule.new,
  AvoidWebsocketMemoryLeakRule.new,
  CheckMountedAfterAsyncRule.new,
  DisposeGetxFieldsRule.new,
  NoMagicNumberInTestsRule.new,
  NoMagicStringInTestsRule.new,
  PreferBlocListenerForSideEffectsRule.new,
  PreferBlocTransformRule.new,
  PreferCachedImageFadeAnimationRule.new,
  PreferChangeNotifierProxyRule.new,
  PreferConstructorInjectionRule.new,
  PreferContextReadInCallbacksRule.new,
  PreferCubitForSimpleStateRule.new,
  PreferDioBaseOptionsRule.new,
  PreferDisposeBeforeNewInstanceRule.new,
  PreferEquatableStringifyRule.new,
  PreferFreezedDefaultValuesRule.new,
  PreferFutureWaitRule.new,
  PreferGetxBuilderRule.new,
  PreferGoRouterRedirectAuthRule.new,
  PreferImagePickerRequestFullMetadataRule.new,
  PreferImmutableAnnotationRule.new,
  PreferIsarAsyncWritesRule.new,
  PreferIsarBatchOperationsRule.new,
  PreferIsarCompositeIndexRule.new,
  PreferIsarIndexForQueriesRule.new,
  PreferIsarLazyLinksRule.new,
  PreferIsarQueryStreamRule.new,
  PreferMaybePopRule.new,
  PreferSelectorOverConsumerRule.new,
  PreferSelectorWidgetRule.new,
  PreferWebViewJavaScriptDisabledRule.new,
  ProperGetxSuperCallsRule.new,
  RequireAnimatedBuilderChildRule.new,
  RequireBlocConsumerWhenBothRule.new,
  RequireBlocErrorStateRule.new,
  RequireBlocEventSealedRule.new,
  RequireBlocInitialStateRule.new,
  RequireBlocLoadingStateRule.new,
  RequireBlocRepositoryAbstractionRule.new,
  RequireChangeNotifierDisposeRule.new,
  RequireConnectivitySubscriptionCancelRule.new,
  RequireDatabaseCloseRule.new,
  RequireDebouncerCancelRule.new,
  RequireDioSingletonRule.new,
  RequireDisposeImplementationRule.new,
  RequireEnumUnknownValueRule.new,
  RequireEquatablePropsOverrideRule.new,
  RequireFileHandleCloseRule.new,
  RequireFlutterRiverpodPackageRule.new,
  RequireFreezedArrowSyntaxRule.new,
  RequireFreezedExplicitJsonRule.new,
  RequireFreezedPrivateConstructorRule.new,
  RequireGeolocatorTimeoutRule.new,
  RequireGetxBindingRule.new,
  RequireGetxControllerDisposeRule.new,
  RequireGoRouterTypedParamsRule.new,
  RequireHiveTypeIdManagementRule.new,
  RequireHttpsOverHttpRule.new,
  RequireImageErrorFallbackRule.new,
  RequireImagePickerErrorHandlingRule.new,
  RequireImagePickerPermissionAndroidRule.new,
  RequireImagePickerPermissionIosRule.new,
  RequireImagePickerResultHandlingRule.new,
  RequireImagePickerSourceChoiceRule.new,
  RequireIntervalTimerCancelRule.new,
  RequireIntlLocaleInitializationRule.new,
  RequireIsarCloseOnDisposeRule.new,
  RequireIsarCollectionAnnotationRule.new,
  RequireIsarIdFieldRule.new,
  RequireIsarInspectorDebugOnlyRule.new,
  RequireIsarLinksLoadRule.new,
  RequireIsarNullableFieldRule.new,
  RequireNotificationHandlerTopLevelRule.new,
  RequireNotificationInitializePerPlatformRule.new,
  RequireNotificationPermissionAndroid13Rule.new,
  RequireNotificationTimezoneAwarenessRule.new,
  RequireNullSafeJsonAccessRule.new,
  RequirePermissionDeniedHandlingRule.new,
  RequirePermissionManifestAndroidRule.new,
  RequirePermissionPlistIosRule.new,
  RequirePermissionRationaleRule.new,
  RequirePermissionStatusCheckRule.new,
  RequirePhysicsForNestedScrollRule.new,
  RequireProviderGenericTypeRule.new,
  RequireReceivePortCloseRule.new,
  RequireRethrowPreserveStackRule.new,
  RequireSecureStorageAuthDataRule.new,
  RequireSocketCloseRule.new,
  RequireSqfliteMigrationRule.new,
  RequireSuperDisposeCallRule.new,
  RequireSuperInitStateCallRule.new,
  RequireTextFormFieldInFormRule.new,
  RequireUrlLauncherErrorHandlingRule.new,
  RequireUrlLauncherModeRule.new,
  RequireUrlLauncherQueriesAndroidRule.new,
  RequireUrlLauncherSchemesIosRule.new,
  RequireValidatorReturnNullRule.new,
  RequireVideoPlayerControllerDisposeRule.new,
  RequireWebViewErrorHandlingRule.new,
  RequireWebViewNavigationDelegateRule.new,
  RequireWebViewProgressIndicatorRule.new,
  RequireWssOverWsRule.new,

  // Windows platform rules (windows_rules.dart)
  AvoidHardcodedDriveLettersRule.new,
  AvoidForwardSlashPathAssumptionRule.new,
  AvoidCaseSensitivePathComparisonRule.new,
  RequireWindowsSingleInstanceCheckRule.new,
  AvoidMaxPathRiskRule.new,

  // Linux platform rules (linux_rules.dart)
  AvoidHardcodedUnixPathsRule.new,
  PreferXdgDirectoryConventionRule.new,
  AvoidX11OnlyAssumptionsRule.new,
  RequireLinuxFontFallbackRule.new,
  AvoidSudoShellCommandsRule.new,
];

// =============================================================================
// LAZY RULE NAME -> FACTORY MAP
// =============================================================================
// Built once on first access. Creates temporary instances to get rule names,
// then discards them. Only the factory references are kept in memory.
// This allows tier filtering without keeping all 1600+ rules in memory.

/// Lazy name→factory map, built once on first access.
late final Map<String, LintRule Function()> _ruleFactories =
    _buildRuleFactoriesMap();

Map<String, LintRule Function()> _buildRuleFactoriesMap() {
  final map = <String, LintRule Function()>{};
  for (final factory in _allRuleFactories) {
    final rule = factory(); // temporary instance to get name
    map[rule.code.name] = factory;
    // rule goes out of scope, can be GC'd
  }
  return map;
}

/// Get rules for a set of rule names.
///
/// Only instantiates rules that are in the provided set.
/// This is the key optimization - for essential tier (253 rules),
/// only 253 rules are created instead of all 1600+.
List<LintRule> getRulesFromRegistry(Set<String> ruleNames) {
  final rules = <LintRule>[];
  for (final name in ruleNames) {
    final factory = _ruleFactories[name];
    if (factory != null) {
      rules.add(factory());
    }
  }
  return rules;
}

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
    // Tier configuration: custom_lint does not support arbitrary plugin
    // config keys, so YAML-based tier selection is unreliable. The
    // recommended approach is `dart run saropa_lints:init --tier <name>`
    // which generates explicit rule lists. This fallback reads from
    // configs.rules['saropa_lints'] in case a user added it as a rule
    // entry, but it will almost always be null (defaulting to essential).
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
    // ISSUE LIMIT CONFIGURATION
    // =========================================================================
    // Configure maximum issues to report before stopping detailed tracking.
    // Read from analysis_options_custom.yaml in project root:
    //   max_issues: 500  # default: 1000, 0 = unlimited
    // This file is read directly (not via custom_lint config).
    _loadMaxIssuesConfig();

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

      // File discovery for progress % is now handled automatically
      // in ProgressTracker.recordFile() using the first analyzed file's path
      // to derive the actual project root (fixes wrong CWD in plugin mode).
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

    // =========================================================================
    // LAZY RULE LOADING (Memory Optimization)
    // =========================================================================
    // Instead of iterating over ALL 1500+ rules and filtering, we:
    // 1. Determine which rule NAMES should be enabled
    // 2. Only instantiate those specific rules from the registry
    // This reduces memory usage significantly for lower tiers.

    // Step 1: Determine which rules to enable
    final Set<String> enabledRuleNames = <String>{};

    if (enableAll) {
      // Enable all registered rules
      enabledRuleNames.addAll(_ruleFactories.keys);
    } else {
      // Start with tier rules
      enabledRuleNames.addAll(tierRules);
    }

    // Step 2: Apply explicit overrides from config
    for (final entry in configs.rules.entries) {
      final ruleName = entry.key;
      if (ruleName == 'saropa_lints') continue; // Skip meta-config

      final options = entry.value;
      if (options.enabled) {
        // Explicitly enabled - add even if not in tier
        enabledRuleNames.add(ruleName);
      } else {
        // Explicitly disabled - remove even if in tier
        enabledRuleNames.remove(ruleName);
      }
    }

    // Step 3: Instantiate only the needed rules from registry
    final List<LintRule> filteredRules = getRulesFromRegistry(enabledRuleNames);

    // =========================================================================
    // UNRESOLVABLE RULE DETECTION (Diagnostic)
    // =========================================================================
    // Warn about rules listed in tier definitions or explicit config but
    // missing from _ruleFactories. This catches orphaned entries that cause
    // the init command's rule count to diverge from the plugin's loaded count.
    final Set<String> loadedNames =
        filteredRules.map((LintRule r) => r.code.name).toSet();
    final Set<String> unresolvable = enabledRuleNames.difference(loadedNames);
    if (unresolvable.isNotEmpty) {
      // ignore: avoid_print
      print(
        '[saropa_lints] WARNING: ${unresolvable.length} rule(s) could not be '
        'resolved (defined in tier/config but missing from rule registry): '
        '${unresolvable.take(10).join(', ')}'
        '${unresolvable.length > 10 ? '...' : ''}',
      );
    }

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

    // Infer the effective tier from the final enabled rule set so the log
    // message reflects reality (the YAML `tier` field is almost always null,
    // defaulting to 'essential', while the actual rules come from explicit
    // overrides generated by `dart run saropa_lints:init`).
    final String effectiveTier =
        enableAll ? 'all' : _inferEffectiveTier(enabledRuleNames);

    // Debug: show rule count to help diagnose "No issues found" problems
    // ignore: avoid_print
    print(
        '[saropa_lints] Loaded ${filteredRules.length} rules (tier: $effectiveTier, enableAll: $enableAll)');

    // Tell progress tracker how many rules are active
    ProgressTracker.setEnabledRuleCount(filteredRules.length);

    return filteredRules;
  }

  /// Infers the effective tier by finding the highest tier whose rules are
  /// all present in [enabledRuleNames].
  String _inferEffectiveTier(Set<String> enabledRuleNames) {
    // Check from highest to lowest — first full match wins.
    const tiers = [
      'pedantic',
      'comprehensive',
      'professional',
      'recommended',
      'essential',
    ];
    for (final candidate in tiers) {
      final tierRules = getRulesForTier(candidate);
      if (tierRules.difference(enabledRuleNames).isEmpty) {
        return candidate;
      }
    }
    return 'custom';
  }
}

/// Conflicting rule pairs that should not be enabled together.
///
/// These are stylistic choices where enabling both makes no sense.
/// Each pair contains two mutually exclusive rules.
const List<List<String>> _conflictingRulePairs = <List<String>>[
  // Type inference vs explicit types
  <String>['prefer_inferred_type_arguments', 'prefer_explicit_type_arguments'],
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

/// Load max_issues config from analysis_options_custom.yaml.
///
/// Reads directly from the project's custom config file:
/// ```yaml
/// # In analysis_options_custom.yaml
/// max_issues: 500  # Limit warning/info tracking (errors always tracked)
/// ```
void _loadMaxIssuesConfig() {
  try {
    final customConfigFile = File('analysis_options_custom.yaml');
    if (!customConfigFile.existsSync()) return;

    final content = customConfigFile.readAsStringSync();
    // Simple regex to extract max_issues value
    // Matches: max_issues: 500 or max_issues:500
    final match = RegExp(r'max_issues:\s*(\d+)').firstMatch(content);
    if (match != null) {
      final value = int.tryParse(match.group(1)!);
      if (value != null) {
        ProgressTracker.setMaxIssues(value);
      }
    }
  } catch (_) {
    // Silently ignore - use default if config can't be read
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
