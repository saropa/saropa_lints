import 'package:saropa_lints/src/rules/architecture/structure_rules.dart';
import 'package:saropa_lints/src/rules/code_quality/code_quality_avoid_rules.dart';
import 'package:saropa_lints/src/rules/code_quality/code_quality_control_flow_rules.dart';
import 'package:saropa_lints/src/rules/code_quality/code_quality_prefer_rules.dart';
import 'package:saropa_lints/src/rules/code_quality/code_quality_variables_rules.dart';
import 'package:saropa_lints/src/rules/code_quality/complexity_rules.dart';
import 'package:saropa_lints/src/rules/code_quality/unnecessary_code_rules.dart';
import 'package:saropa_lints/src/rules/core/async_rules.dart';
import 'package:saropa_lints/src/rules/data/collection_rules.dart';
import 'package:saropa_lints/src/rules/data/equality_rules.dart';
import 'package:saropa_lints/src/rules/data/numeric_literal_rules.dart';
import 'package:saropa_lints/src/rules/data/type_rules.dart';
import 'package:saropa_lints/src/rules/flow/control_flow_rules.dart';
import 'package:saropa_lints/src/rules/flow/exception_rules.dart';
import 'package:saropa_lints/src/rules/flow/return_rules.dart';
import 'package:saropa_lints/src/rules/stylistic/formatting_rules.dart';
import 'package:saropa_lints/src/rules/stylistic/stylistic_additional_rules.dart';
import 'package:saropa_lints/src/rules/stylistic/stylistic_rules.dart';
import 'package:saropa_lints/src/rules/ui/animation_rules.dart';
import 'package:saropa_lints/src/rules/widget/flutter_migration_widget_rules.dart';
import 'package:test/test.dart';

/// Unit tests that assert quick-fix registration for rules that provide fixes.
///
/// **Purpose for developers:**
/// - **100 positive tests:** Each listed rule is expected to provide at least
///   one quick fix. The test instantiates the rule and asserts
///   `rule.fixGenerators` is non-empty. This catches accidental removal of
///   fix registration (e.g. when refactoring or renaming a rule).
/// - **1 inverse test:** A rule known to have no quick fix
///   ([AvoidNonFinalExceptionClassFieldsRule]) must have empty
///   `fixGenerators`. This guards against the test logic being wrong (e.g.
///   if `fixGenerators` were changed to always return a non-empty list).
///
/// **Scope:** Only rules from already-imported rule files are covered. Adding
/// a new rule with quick fixes: add a corresponding `hasFix('RuleName', ...)`
/// call and keep exactly one test per rule (no duplicates).
///
/// **Not covered here:** Lint behavior (e.g. BAD/GOOD code triggering or not)
/// is tested in rule-specific test files and in `example*/` fixtures; see
/// CONTRIBUTING.md and bugs/discussion/TESTING_AND_RELEASE.md.
void main() {
  group('Rule quick fix presence', () {
    void hasFix(String name, dynamic Function() create) {
      test('$name has at least one quick fix', () {
        final rule = create();
        expect(rule.fixGenerators, isNotEmpty, reason: name);
      });
    }

    test('rule without quick fix has empty fixGenerators', () {
      final rule = AvoidNonFinalExceptionClassFieldsRule();
      expect(rule.fixGenerators, isEmpty);
    });

    // Code quality - avoid (17)
    hasFix('AvoidAdjacentStringsRule', () => AvoidAdjacentStringsRule());
    hasFix('AvoidLateKeywordRule', () => AvoidLateKeywordRule());
    hasFix('AvoidMisusedSetLiteralsRule', () => AvoidMisusedSetLiteralsRule());
    hasFix('AvoidStringSubstringRule', () => AvoidSubstringRule());
    hasFix('AvoidUnknownPragmaRule', () => AvoidUnknownPragmaRule());
    hasFix('AvoidUnusedParametersRule', () => AvoidUnusedParametersRule());
    hasFix(
      'AvoidWeakCryptographicAlgorithmsRule',
      () => AvoidWeakCryptographicAlgorithmsRule(),
    );
    hasFix('NoObjectDeclarationRule', () => NoObjectDeclarationRule());
    hasFix(
      'AvoidPassingDefaultValuesRule',
      () => AvoidPassingDefaultValuesRule(),
    );
    hasFix(
      'AvoidRedundantPragmaInlineRule',
      () => AvoidRedundantPragmaInlineRule(),
    );
    hasFix(
      'AvoidAlwaysNullParametersRule',
      () => AvoidAlwaysNullParametersRule(),
    );
    hasFix(
      'AvoidAssigningToStaticFieldRule',
      () => AvoidAssigningToStaticFieldRule(),
    );
    hasFix(
      'AvoidDuplicateInitializersRule',
      () => AvoidDuplicateInitializersRule(),
    );
    hasFix(
      'AvoidUnnecessaryOverridesRule',
      () => AvoidUnnecessaryOverridesRule(),
    );
    hasFix(
      'AvoidUnnecessaryStatementsRule',
      () => AvoidUnnecessaryStatementsRule(),
    );
    hasFix('AvoidEmptyBuildWhenRule', () => AvoidEmptyBuildWhenRule());
    hasFix('AvoidUnnecessaryFuturesRule', () => AvoidUnnecessaryFuturesRule());
    hasFix(
      'AvoidUnnecessaryNullableReturnTypeRule',
      () => AvoidUnnecessaryNullableReturnTypeRule(),
    );
    hasFix('AvoidThrowInCatchBlockRule', () => AvoidThrowInCatchBlockRule());
    hasFix(
      'PreferPublicExceptionClassesRule',
      () => PreferPublicExceptionClassesRule(),
    );

    // Code quality - control flow (6)
    hasFix('NoEqualNestedConditionsRule', () => NoEqualNestedConditionsRule());
    hasFix('NoEqualSwitchCaseRule', () => NoEqualSwitchCaseRule());
    hasFix('AvoidDuplicatePatternsRule', () => AvoidDuplicatePatternsRule());
    hasFix(
      'NoEqualSwitchExpressionCasesRule',
      () => NoEqualSwitchExpressionCasesRule(),
    );
    hasFix(
      'RequireExhaustiveSealedSwitchRule',
      () => RequireExhaustiveSealedSwitchRule(),
    );
    hasFix(
      'AvoidWildcardCasesWithEnumsRule',
      () => AvoidWildcardCasesWithEnumsRule(),
    );

    // Code quality - prefer (8)
    hasFix('PreferDotShorthandRule', () => PreferDotShorthandRule());
    hasFix(
      'PreferReturningConditionalExpressionsRule',
      () => PreferReturningConditionalExpressionsRule(),
    );
    hasFix('PreferUsePrefixRule', () => PreferUsePrefixRule());
    hasFix('PreferNullAwareSpreadRule', () => PreferNullAwareSpreadRule());
    hasFix('PreferAnyOrEveryRule', () => PreferAnyOrEveryRule());
    hasFix('PreferTestMatchersRule', () => PreferTestMatchersRule());
    hasFix('PreferEnumsByNameRule', () => PreferEnumsByNameRule());
    hasFix('NoBooleanLiteralCompareRule', () => NoBooleanLiteralCompareRule());

    // Control flow (12)
    hasFix(
      'AvoidAssignmentsAsConditionsRule',
      () => AvoidAssignmentsAsConditionsRule(),
    );
    hasFix(
      'AvoidConstantAssertConditionsRule',
      () => AvoidConstantAssertConditionsRule(),
    );
    hasFix(
      'AvoidDuplicateSwitchCaseConditionsRule',
      () => AvoidDuplicateSwitchCaseConditionsRule(),
    );
    hasFix('AvoidRedundantElseRule', () => AvoidRedundantElseRule());
    hasFix('AvoidUnconditionalBreakRule', () => AvoidUnconditionalBreakRule());
    hasFix(
      'AvoidUnnecessaryContinueRule',
      () => AvoidUnnecessaryContinueRule(),
    );
    hasFix(
      'PreferSimplerBooleanExpressionsRule',
      () => PreferSimplerBooleanExpressionsRule(),
    );
    hasFix(
      'AvoidConditionsWithBooleanLiteralsRule',
      () => AvoidConditionsWithBooleanLiteralsRule(),
    );
    hasFix(
      'AvoidInvertedBooleanChecksRule',
      () => AvoidInvertedBooleanChecksRule(),
    );
    hasFix('AvoidNegatedConditionsRule', () => AvoidNegatedConditionsRule());
    hasFix('NoEqualThenElseRule', () => NoEqualThenElseRule());
    hasFix('AvoidConstantConditionsRule', () => AvoidConstantConditionsRule());

    // Return (8)
    hasFix('AvoidReturningCascadesRule', () => AvoidReturningCascadesRule());
    hasFix('AvoidReturningThisRule', () => AvoidReturningThisRule());
    hasFix('AvoidReturningVoidRule', () => AvoidReturningVoidRule());
    hasFix('AvoidUnnecessaryReturnRule', () => AvoidUnnecessaryReturnRule());
    hasFix('PreferImmediateReturnRule', () => PreferImmediateReturnRule());
    hasFix(
      'PreferReturningShorthandsRule',
      () => PreferReturningShorthandsRule(),
    );
    hasFix(
      'AvoidReturningNullForVoidRule',
      () => AvoidReturningNullForVoidRule(),
    );
    hasFix(
      'AvoidReturningNullForFutureRule',
      () => AvoidReturningNullForFutureRule(),
    );

    // Collection (14)
    hasFix('AvoidDuplicateMapKeysRule', () => AvoidDuplicateMapKeysRule());
    hasFix('PreferContainsRule', () => PreferContainsRule());
    hasFix('PreferFirstRule', () => PreferFirstRule());
    hasFix(
      'AvoidDuplicateNumberElementsRule',
      () => AvoidDuplicateNumberElementsRule(),
    );
    hasFix(
      'AvoidDuplicateStringElementsRule',
      () => AvoidDuplicateStringElementsRule(),
    );
    hasFix(
      'AvoidDuplicateObjectElementsRule',
      () => AvoidDuplicateObjectElementsRule(),
    );
    hasFix('RequireConstListItemsRule', () => RequireConstListItemsRule());
    hasFix('AvoidMapKeysContainsRule', () => AvoidMapKeysContainsRule());
    hasFix('PreferLastRule', () => PreferLastRule());
    hasFix('PreferWhereOrNullRule', () => PreferWhereOrNullRule());
    hasFix('AvoidUnsafeWhereMethodsRule', () => AvoidUnsafeWhereMethodsRule());
    hasFix(
      'AvoidUnnecessaryCollectionsRule',
      () => AvoidUnnecessaryCollectionsRule(),
    );
    hasFix(
      'PreferCorrectForLoopIncrementRule',
      () => PreferCorrectForLoopIncrementRule(),
    );

    // Async (2)
    hasFix('AvoidFutureIgnoreRule', () => AvoidFutureIgnoreRule());
    hasFix('AvoidRedundantAsyncRule', () => AvoidRedundantAsyncRule());

    // Structure (10)
    hasFix('AvoidThrowInFinallyRule', () => AvoidThrowInFinallyRule());
    hasFix('AvoidDoubleSlashImportsRule', () => AvoidDoubleSlashImportsRule());
    hasFix(
      'AvoidDuplicateNamedImportsRule',
      () => AvoidDuplicateNamedImportsRule(),
    );
    hasFix('AvoidDuplicateExportsRule', () => AvoidDuplicateExportsRule());
    hasFix('AvoidDuplicateMixinsRule', () => AvoidDuplicateMixinsRule());
    hasFix(
      'AvoidUnnecessaryLocalVariableRule',
      () => AvoidUnnecessaryLocalVariableRule(),
    );
    hasFix(
      'AvoidUnnecessaryReassignmentRule',
      () => AvoidUnnecessaryReassignmentRule(),
    );
    hasFix(
      'PreferTrailingUnderscoreForUnusedRule',
      () => PreferTrailingUnderscoreForUnusedRule(),
    );

    // Formatting (4)
    hasFix('NewlineBeforeElseRule', () => NewlineBeforeElseRule());
    hasFix('NewlineAfterLoopRule', () => NewlineAfterLoopRule());
    hasFix('PreferTrailingCommaRule', () => PreferTrailingCommaRule());
    hasFix(
      'UnnecessaryTrailingCommaRule',
      () => UnnecessaryTrailingCommaRule(),
    );

    // Equality (1)
    hasFix('AvoidSelfAssignmentRule', () => AvoidSelfAssignmentRule());

    // Exception (1)
    hasFix('AvoidOnlyRethrowRule', () => AvoidOnlyRethrowRule());

    // Complexity (3)
    hasFix(
      'PreferParenthesesWithIfNullRule',
      () => PreferParenthesesWithIfNullRule(),
    );
    hasFix('AvoidDuplicateCascadesRule', () => AvoidDuplicateCascadesRule());
    hasFix('AvoidCascadeAfterIfNullRule', () => AvoidCascadeAfterIfNullRule());

    // Unnecessary code (2)
    hasFix('AvoidUnnecessaryGetterRule', () => AvoidUnnecessaryGetterRule());
    hasFix('AvoidCommentedOutCodeRule', () => AvoidCommentedOutCodeRule());

    // Type (2)
    hasFix('PreferFinalLocalsRule', () => PreferFinalLocalsRule());
    hasFix('PreferConstDeclarationsRule', () => PreferConstDeclarationsRule());

    // Stylistic (stylistic_rules + stylistic_additional) (7)
    hasFix('PreferSingleQuotesRule', () => PreferSingleQuotesRule());
    hasFix('PreferDoubleQuotesRule', () => PreferDoubleQuotesRule());
    hasFix(
      'PreferSentenceCaseCommentsRule',
      () => PreferSentenceCaseCommentsRule(),
    );
    hasFix(
      'PreferStraightApostropheRule',
      () => PreferStraightApostropheRule(),
    );
    hasFix('PreferCurlyApostropheRule', () => PreferCurlyApostropheRule());
    hasFix('ArgumentsOrderingRule', () => ArgumentsOrderingRule());

    // Numeric literal (3)
    hasFix('PreferDigitSeparatorsRule', () => PreferDigitSeparatorsRule());
    hasFix('DoubleLiteralFormatRule', () => DoubleLiteralFormatRule());
    hasFix(
      'AvoidUnnecessaryDigitSeparatorsRule',
      () => AvoidUnnecessaryDigitSeparatorsRule(),
    );

    // Code quality variables (1)
    hasFix('AvoidUnusedAssignmentRule', () => AvoidUnusedAssignmentRule());

    // Flutter migration widget (1)
    hasFix('PreferSuperKeyRule', () => PreferSuperKeyRule());

    // UI / Animation (1)
    hasFix(
      'AvoidImplicitAnimationDisposeCastRule',
      () => AvoidImplicitAnimationDisposeCastRule(),
    );
  });
}
