// ignore_for_file: depend_on_referenced_packages

/// A [RuleVisitorRegistry] that captures visitors instead of registering
/// them with the analysis server.
///
/// Used by the standalone scan command to intercept the [CompatVisitor]
/// instances that rules register during [registerNodeProcessors].
/// Each rule creates one [CompatVisitor] and passes it to multiple `addXxx`
/// calls — we deduplicate by identity and return the unique set.
library;

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart' show AstVisitor;

/// Captures [AstVisitor] instances registered by rules.
///
/// All `addXxx` methods store the visitor; the scan runner retrieves
/// them via [capturedVisitors] and walks the AST manually.
class CapturingRuleVisitorRegistry implements RuleVisitorRegistry {
  final List<AstVisitor> _visitors = [];
  final Set<AstVisitor> _seen = {};

  /// The unique visitors captured from rule registration.
  List<AstVisitor> get capturedVisitors => List.unmodifiable(_visitors);

  /// Callbacks registered via [afterLibrary].
  final List<void Function()> _afterLibraryCallbacks = [];

  /// Post-library callbacks from rules.
  List<void Function()> get afterLibraryCallbacks =>
      List.unmodifiable(_afterLibraryCallbacks);

  void _capture(AstVisitor visitor) {
    if (_seen.add(visitor)) {
      _visitors.add(visitor);
    }
  }

  // =========================================================================
  // RuleVisitorRegistry implementation — all delegate to _capture
  // =========================================================================

  @override
  void addAdjacentStrings(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addAnnotation(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addArgumentList(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addAsExpression(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addAssertInitializer(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addAssertStatement(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addAssignedVariablePattern(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addAssignmentExpression(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addAwaitExpression(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addBinaryExpression(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addBlock(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addBlockClassBody(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addBlockFunctionBody(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addBooleanLiteral(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addBreakStatement(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addCascadeExpression(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addCaseClause(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addCastPattern(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addCatchClause(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addCatchClauseParameter(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addClassDeclaration(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addClassTypeAlias(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addComment(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addCommentReference(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addCompilationUnit(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addConditionalExpression(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addConfiguration(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addConstantPattern(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addConstructorDeclaration(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addConstructorFieldInitializer(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addConstructorName(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addConstructorReference(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addConstructorSelector(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addContinueStatement(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addDeclaredIdentifier(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addDeclaredVariablePattern(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addDefaultFormalParameter(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addDoStatement(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addDotShorthandConstructorInvocation(
    AbstractAnalysisRule r,
    AstVisitor v,
  ) =>
      _capture(v);
  @override
  void addDotShorthandInvocation(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addDotShorthandPropertyAccess(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addDottedName(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addDoubleLiteral(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addEmptyClassBody(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addEmptyFunctionBody(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addEmptyStatement(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addEnumBody(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addEnumConstantArguments(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addEnumConstantDeclaration(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addEnumDeclaration(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addExportDirective(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addExpressionFunctionBody(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addExpressionStatement(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addExtendsClause(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addExtensionDeclaration(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addExtensionOnClause(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addExtensionOverride(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addExtensionTypeDeclaration(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addFieldDeclaration(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addFieldFormalParameter(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addForEachPartsWithDeclaration(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addForEachPartsWithIdentifier(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addForEachPartsWithPattern(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addForElement(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addFormalParameterList(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addForPartsWithDeclarations(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addForPartsWithExpression(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addForPartsWithPattern(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addForStatement(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addFunctionDeclaration(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addFunctionDeclarationStatement(
    AbstractAnalysisRule r,
    AstVisitor v,
  ) =>
      _capture(v);
  @override
  void addFunctionExpression(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addFunctionExpressionInvocation(
    AbstractAnalysisRule r,
    AstVisitor v,
  ) =>
      _capture(v);
  @override
  void addFunctionReference(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addFunctionTypeAlias(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addFunctionTypedFormalParameter(
    AbstractAnalysisRule r,
    AstVisitor v,
  ) =>
      _capture(v);
  @override
  void addGenericFunctionType(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addGenericTypeAlias(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addGuardedPattern(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addHideCombinator(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addIfElement(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addIfStatement(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addImplementsClause(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addImplicitCallReference(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addImportDirective(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addImportPrefixReference(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addIndexExpression(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addInstanceCreationExpression(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addIntegerLiteral(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addInterpolationExpression(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addInterpolationString(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addIsExpression(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addLabel(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addLabeledStatement(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addLibraryDirective(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addLibraryIdentifier(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addListLiteral(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addListPattern(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addLogicalAndPattern(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addLogicalOrPattern(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addMapLiteralEntry(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addMapPattern(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addMapPatternEntry(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addMethodDeclaration(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addMethodInvocation(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addMixinDeclaration(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addMixinOnClause(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addNamedExpression(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addNamedType(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addNameWithTypeParameters(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addNativeClause(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addNativeFunctionBody(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addNullAssertPattern(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addNullAwareElement(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addNullCheckPattern(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addNullLiteral(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addObjectPattern(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addParenthesizedExpression(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addParenthesizedPattern(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addPartDirective(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addPartOfDirective(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addPatternAssignment(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addPatternField(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addPatternFieldName(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addPatternVariableDeclaration(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addPatternVariableDeclarationStatement(
    AbstractAnalysisRule r,
    AstVisitor v,
  ) =>
      _capture(v);
  @override
  void addPostfixExpression(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addPrefixedIdentifier(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addPrefixExpression(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addPrimaryConstructorDeclaration(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addPrimaryConstructorName(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addPropertyAccess(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addRecordLiteral(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addRecordPattern(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addRecordTypeAnnotation(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addRecordTypeAnnotationNamedField(
    AbstractAnalysisRule r,
    AstVisitor v,
  ) =>
      _capture(v);
  @override
  void addRecordTypeAnnotationNamedFields(
    AbstractAnalysisRule r,
    AstVisitor v,
  ) =>
      _capture(v);
  @override
  void addRecordTypeAnnotationPositionalField(
    AbstractAnalysisRule r,
    AstVisitor v,
  ) =>
      _capture(v);
  @override
  void addRedirectingConstructorInvocation(
    AbstractAnalysisRule r,
    AstVisitor v,
  ) =>
      _capture(v);
  @override
  void addRelationalPattern(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addRepresentationConstructorName(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addRepresentationDeclaration(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addRestPatternElement(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addRethrowExpression(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addReturnStatement(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addScriptTag(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addSetOrMapLiteral(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addShowCombinator(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addSimpleFormalParameter(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addSimpleIdentifier(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addSimpleStringLiteral(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addSpreadElement(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addStringInterpolation(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addSuperConstructorInvocation(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addSuperExpression(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addSuperFormalParameter(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addSwitchCase(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addSwitchDefault(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addSwitchExpression(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addSwitchExpressionCase(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addSwitchPatternCase(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addSwitchStatement(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addSymbolLiteral(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addThisExpression(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addThrowExpression(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addTopLevelVariableDeclaration(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addTryStatement(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addTypeArgumentList(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addTypeLiteral(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addTypeParameter(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addTypeParameterList(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addVariableDeclaration(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addVariableDeclarationList(AbstractAnalysisRule r, AstVisitor v) =>
      _capture(v);
  @override
  void addVariableDeclarationStatement(
    AbstractAnalysisRule r,
    AstVisitor v,
  ) =>
      _capture(v);
  @override
  void addWhenClause(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addWhileStatement(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addWildcardPattern(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addWithClause(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void addYieldStatement(AbstractAnalysisRule r, AstVisitor v) => _capture(v);
  @override
  void afterLibrary(AbstractAnalysisRule r, void Function() callback) {
    _afterLibraryCallbacks.add(callback);
  }
}
