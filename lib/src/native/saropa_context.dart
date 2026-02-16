// ignore_for_file: depend_on_referenced_packages

/// Registry wrapper that provides the callback-based `addXxx((node) {...})`
/// API that existing saropa_lints rules use.
///
/// Internally, it stores callbacks in a [CompatVisitor] and registers that
/// visitor with the native [RuleVisitorRegistry].
///
/// Old pattern: `context.registry.addMethodInvocation((node) { ... })`
/// New pattern: `context.addMethodInvocation((node) { ... })`
library;

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/line_info.dart';

import '../project_context.dart' show FileTypeDetector;
import '../saropa_lint_rule.dart' show SaropaLintRule;
import 'compat_visitor.dart';

/// Wraps [RuleVisitorRegistry] to provide callback-based registration.
///
/// Each `addXxx(callback)` method:
/// 1. Stores the callback in the [CompatVisitor]
/// 2. Registers the visitor with the native registry for that node type
///
/// When the analyzer walks the AST, it calls the visitor's `visitXxx` method,
/// which dispatches to the stored callback.
class SaropaContext {
  SaropaContext(this._registry, this._rule, this._ruleContext)
    : _visitor = CompatVisitor(),
      _saropaRule = _rule is SaropaLintRule ? _rule : null;

  final RuleVisitorRegistry _registry;
  final AbstractAnalysisRule _rule;
  final RuleContext _ruleContext;
  final CompatVisitor _visitor;

  /// Typed reference for per-file filtering. Null if rule is not a
  /// [SaropaLintRule] (e.g. the PoC rules used [SaropaAnalysisRule]).
  final SaropaLintRule? _saropaRule;

  // ===========================================================================
  // File access
  // ===========================================================================

  /// The content of the file being analyzed.
  String get fileContent => _ruleContext.currentUnit?.content ?? '';

  /// The path of the file being analyzed.
  String get filePath => _ruleContext.currentUnit?.file.path ?? '';

  /// Whether the file is in a test directory.
  bool get isInTestDirectory => _ruleContext.isInTestDirectory;

  /// Whether the file is in a lib directory.
  bool get isInLibDir => _ruleContext.isInLibDir;

  /// Line info for the current file.
  ///
  /// Provides line/column lookup via `lineInfo.getLocation(offset)`.
  /// Only valid during AST visiting (not during registration).
  // ignore: lines_longer_than_80_chars
  LineInfo get lineInfo => _ruleContext.currentUnit!.unit.lineInfo;

  // ===========================================================================
  // Per-file filtering
  // ===========================================================================

  /// Cache: last file path checked and its skip result.
  /// Avoids re-evaluating for every node in the same file.
  String? _lastCheckedPath;
  bool _lastSkipResult = false;

  /// Wraps a callback with per-file filtering based on rule metadata.
  ///
  /// The wrapped callback checks the current file against the rule's
  /// [SaropaLintRule.applicableFileTypes], [SaropaLintRule.requiredPatterns],
  /// and other filtering properties. If the file should be skipped, the
  /// callback returns without invoking the original.
  ///
  /// If the rule is not a [SaropaLintRule], returns the callback unchanged.
  void Function(T) _wrapCallback<T extends AstNode>(void Function(T) callback) {
    if (_saropaRule == null) return callback;
    return (T node) {
      if (_shouldSkipCurrentFile()) return;
      callback(node);
    };
  }

  /// Checks whether the current file should be skipped for this rule.
  ///
  /// Result is cached per file path so it runs at most once per file,
  /// not once per AST node.
  bool _shouldSkipCurrentFile() {
    final path = filePath;
    if (path.isEmpty) return false;
    if (path == _lastCheckedPath) return _lastSkipResult;
    _lastCheckedPath = path;

    final rule = _saropaRule!;

    // 1. Path-based filtering (generated, test, example, fixture).
    if (rule.shouldSkipFile(path)) {
      return _lastSkipResult = true;
    }

    // Read file content once for all content-based checks.
    final content = fileContent;

    // 2. applicableFileTypes check.
    final applicable = rule.applicableFileTypes;
    if (applicable != null) {
      final fileTypes = FileTypeDetector.detect(path, content);
      if (!applicable.any(fileTypes.contains)) {
        return _lastSkipResult = true;
      }
    }

    // 3. requiredPatterns check.
    final patterns = rule.requiredPatterns;
    if (patterns != null &&
        patterns.isNotEmpty &&
        !patterns.any(content.contains)) {
      return _lastSkipResult = true;
    }

    // 4. Content-based requirements (imports, keywords).
    if (_failsContentRequirements(rule, content)) {
      return _lastSkipResult = true;
    }

    // 5. Line count checks.
    final lineCount = _ruleContext.currentUnit?.unit.lineInfo.lineCount ?? 0;
    if (rule.minimumLineCount > 0 && lineCount < rule.minimumLineCount) {
      return _lastSkipResult = true;
    }
    if (rule.maximumLineCount > 0 && lineCount > rule.maximumLineCount) {
      return _lastSkipResult = true;
    }

    return _lastSkipResult = false;
  }

  /// Returns true if the file content fails any of the rule's
  /// content-based requirements (async, widgets, imports, etc.).
  static bool _failsContentRequirements(SaropaLintRule rule, String content) {
    if (rule.requiresAsync &&
        !content.contains('async') &&
        !content.contains('Future')) {
      return true;
    }
    if (rule.requiresWidgets &&
        !content.contains('Widget') &&
        !content.contains('State<')) {
      return true;
    }
    if (rule.requiresFlutterImport && !content.contains('package:flutter/')) {
      return true;
    }
    if (rule.requiresBlocImport &&
        !content.contains('package:bloc/') &&
        !content.contains('package:flutter_bloc/')) {
      return true;
    }
    if (rule.requiresProviderImport && !content.contains('package:provider/')) {
      return true;
    }
    if (rule.requiresRiverpodImport &&
        !content.contains('package:riverpod/') &&
        !content.contains('package:flutter_riverpod/') &&
        !content.contains('package:hooks_riverpod/')) {
      return true;
    }
    if (rule.requiresClassDeclaration &&
        !content.contains('class ') &&
        !content.contains('mixin ') &&
        !content.contains('extension ')) {
      return true;
    }
    if (rule.requiresMainFunction && !content.contains('void main(')) {
      return true;
    }
    if (rule.requiresImports &&
        !content.contains('import ') &&
        !content.contains('export ')) {
      return true;
    }
    return false;
  }

  // ===========================================================================
  // Node registration methods
  // ===========================================================================
  // Each method stores the callback and registers with the native registry.

  void addAdjacentStrings(void Function(AdjacentStrings) callback) {
    _visitor.onAdjacentStrings = _wrapCallback(callback);
    _registry.addAdjacentStrings(_rule, _visitor);
  }

  void addAnnotation(void Function(Annotation) callback) {
    _visitor.onAnnotation = _wrapCallback(callback);
    _registry.addAnnotation(_rule, _visitor);
  }

  void addArgumentList(void Function(ArgumentList) callback) {
    _visitor.onArgumentList = _wrapCallback(callback);
    _registry.addArgumentList(_rule, _visitor);
  }

  void addAsExpression(void Function(AsExpression) callback) {
    _visitor.onAsExpression = _wrapCallback(callback);
    _registry.addAsExpression(_rule, _visitor);
  }

  void addAssertStatement(void Function(AssertStatement) callback) {
    _visitor.onAssertStatement = _wrapCallback(callback);
    _registry.addAssertStatement(_rule, _visitor);
  }

  void addAssignmentExpression(void Function(AssignmentExpression) callback) {
    _visitor.onAssignmentExpression = _wrapCallback(callback);
    _registry.addAssignmentExpression(_rule, _visitor);
  }

  void addAwaitExpression(void Function(AwaitExpression) callback) {
    _visitor.onAwaitExpression = _wrapCallback(callback);
    _registry.addAwaitExpression(_rule, _visitor);
  }

  void addBinaryExpression(void Function(BinaryExpression) callback) {
    _visitor.onBinaryExpression = _wrapCallback(callback);
    _registry.addBinaryExpression(_rule, _visitor);
  }

  void addBlock(void Function(Block) callback) {
    _visitor.onBlock = _wrapCallback(callback);
    _registry.addBlock(_rule, _visitor);
  }

  void addBlockFunctionBody(void Function(BlockFunctionBody) callback) {
    _visitor.onBlockFunctionBody = _wrapCallback(callback);
    _registry.addBlockFunctionBody(_rule, _visitor);
  }

  void addCascadeExpression(void Function(CascadeExpression) callback) {
    _visitor.onCascadeExpression = _wrapCallback(callback);
    _registry.addCascadeExpression(_rule, _visitor);
  }

  void addCatchClause(void Function(CatchClause) callback) {
    _visitor.onCatchClause = _wrapCallback(callback);
    _registry.addCatchClause(_rule, _visitor);
  }

  void addClassDeclaration(void Function(ClassDeclaration) callback) {
    _visitor.onClassDeclaration = _wrapCallback(callback);
    _registry.addClassDeclaration(_rule, _visitor);
  }

  void addCompilationUnit(void Function(CompilationUnit) callback) {
    _visitor.onCompilationUnit = _wrapCallback(callback);
    _registry.addCompilationUnit(_rule, _visitor);
  }

  void addConditionalExpression(void Function(ConditionalExpression) callback) {
    _visitor.onConditionalExpression = _wrapCallback(callback);
    _registry.addConditionalExpression(_rule, _visitor);
  }

  void addConstructorDeclaration(
    void Function(ConstructorDeclaration) callback,
  ) {
    _visitor.onConstructorDeclaration = _wrapCallback(callback);
    _registry.addConstructorDeclaration(_rule, _visitor);
  }

  void addContinueStatement(void Function(ContinueStatement) callback) {
    _visitor.onContinueStatement = _wrapCallback(callback);
    _registry.addContinueStatement(_rule, _visitor);
  }

  void addDeclaredVariablePattern(
    void Function(DeclaredVariablePattern) callback,
  ) {
    _visitor.onDeclaredVariablePattern = _wrapCallback(callback);
    _registry.addDeclaredVariablePattern(_rule, _visitor);
  }

  void addDefaultFormalParameter(
    void Function(DefaultFormalParameter) callback,
  ) {
    _visitor.onDefaultFormalParameter = _wrapCallback(callback);
    _registry.addDefaultFormalParameter(_rule, _visitor);
  }

  void addDoStatement(void Function(DoStatement) callback) {
    _visitor.onDoStatement = _wrapCallback(callback);
    _registry.addDoStatement(_rule, _visitor);
  }

  void addDoubleLiteral(void Function(DoubleLiteral) callback) {
    _visitor.onDoubleLiteral = _wrapCallback(callback);
    _registry.addDoubleLiteral(_rule, _visitor);
  }

  void addEnumConstantDeclaration(
    void Function(EnumConstantDeclaration) callback,
  ) {
    _visitor.onEnumConstantDeclaration = _wrapCallback(callback);
    _registry.addEnumConstantDeclaration(_rule, _visitor);
  }

  void addEnumDeclaration(void Function(EnumDeclaration) callback) {
    _visitor.onEnumDeclaration = _wrapCallback(callback);
    _registry.addEnumDeclaration(_rule, _visitor);
  }

  void addExportDirective(void Function(ExportDirective) callback) {
    _visitor.onExportDirective = _wrapCallback(callback);
    _registry.addExportDirective(_rule, _visitor);
  }

  void addExpressionStatement(void Function(ExpressionStatement) callback) {
    _visitor.onExpressionStatement = _wrapCallback(callback);
    _registry.addExpressionStatement(_rule, _visitor);
  }

  void addExtensionDeclaration(void Function(ExtensionDeclaration) callback) {
    _visitor.onExtensionDeclaration = _wrapCallback(callback);
    _registry.addExtensionDeclaration(_rule, _visitor);
  }

  void addExtensionTypeDeclaration(
    void Function(ExtensionTypeDeclaration) callback,
  ) {
    _visitor.onExtensionTypeDeclaration = _wrapCallback(callback);
    _registry.addExtensionTypeDeclaration(_rule, _visitor);
  }

  void addFieldDeclaration(void Function(FieldDeclaration) callback) {
    _visitor.onFieldDeclaration = _wrapCallback(callback);
    _registry.addFieldDeclaration(_rule, _visitor);
  }

  void addForEachPartsWithDeclaration(
    void Function(ForEachPartsWithDeclaration) callback,
  ) {
    _visitor.onForEachPartsWithDeclaration = _wrapCallback(callback);
    _registry.addForEachPartsWithDeclaration(_rule, _visitor);
  }

  void addForElement(void Function(ForElement) callback) {
    _visitor.onForElement = _wrapCallback(callback);
    _registry.addForElement(_rule, _visitor);
  }

  void addFormalParameterList(void Function(FormalParameterList) callback) {
    _visitor.onFormalParameterList = _wrapCallback(callback);
    _registry.addFormalParameterList(_rule, _visitor);
  }

  void addForStatement(void Function(ForStatement) callback) {
    _visitor.onForStatement = _wrapCallback(callback);
    _registry.addForStatement(_rule, _visitor);
  }

  void addFunctionDeclaration(void Function(FunctionDeclaration) callback) {
    _visitor.onFunctionDeclaration = _wrapCallback(callback);
    _registry.addFunctionDeclaration(_rule, _visitor);
  }

  void addFunctionDeclarationStatement(
    void Function(FunctionDeclarationStatement) callback,
  ) {
    _visitor.onFunctionDeclarationStatement = _wrapCallback(callback);
    _registry.addFunctionDeclarationStatement(_rule, _visitor);
  }

  void addFunctionExpression(void Function(FunctionExpression) callback) {
    _visitor.onFunctionExpression = _wrapCallback(callback);
    _registry.addFunctionExpression(_rule, _visitor);
  }

  void addFunctionExpressionInvocation(
    void Function(FunctionExpressionInvocation) callback,
  ) {
    _visitor.onFunctionExpressionInvocation = _wrapCallback(callback);
    _registry.addFunctionExpressionInvocation(_rule, _visitor);
  }

  void addGenericFunctionType(void Function(GenericFunctionType) callback) {
    _visitor.onGenericFunctionType = _wrapCallback(callback);
    _registry.addGenericFunctionType(_rule, _visitor);
  }

  void addGenericTypeAlias(void Function(GenericTypeAlias) callback) {
    _visitor.onGenericTypeAlias = _wrapCallback(callback);
    _registry.addGenericTypeAlias(_rule, _visitor);
  }

  void addIfElement(void Function(IfElement) callback) {
    _visitor.onIfElement = _wrapCallback(callback);
    _registry.addIfElement(_rule, _visitor);
  }

  void addIfStatement(void Function(IfStatement) callback) {
    _visitor.onIfStatement = _wrapCallback(callback);
    _registry.addIfStatement(_rule, _visitor);
  }

  void addImportDirective(void Function(ImportDirective) callback) {
    _visitor.onImportDirective = _wrapCallback(callback);
    _registry.addImportDirective(_rule, _visitor);
  }

  void addIndexExpression(void Function(IndexExpression) callback) {
    _visitor.onIndexExpression = _wrapCallback(callback);
    _registry.addIndexExpression(_rule, _visitor);
  }

  void addInstanceCreationExpression(
    void Function(InstanceCreationExpression) callback,
  ) {
    _visitor.onInstanceCreationExpression = _wrapCallback(callback);
    _registry.addInstanceCreationExpression(_rule, _visitor);
  }

  void addIntegerLiteral(void Function(IntegerLiteral) callback) {
    _visitor.onIntegerLiteral = _wrapCallback(callback);
    _registry.addIntegerLiteral(_rule, _visitor);
  }

  void addInterpolationExpression(
    void Function(InterpolationExpression) callback,
  ) {
    _visitor.onInterpolationExpression = _wrapCallback(callback);
    _registry.addInterpolationExpression(_rule, _visitor);
  }

  void addIsExpression(void Function(IsExpression) callback) {
    _visitor.onIsExpression = _wrapCallback(callback);
    _registry.addIsExpression(_rule, _visitor);
  }

  void addLibraryDirective(void Function(LibraryDirective) callback) {
    _visitor.onLibraryDirective = _wrapCallback(callback);
    _registry.addLibraryDirective(_rule, _visitor);
  }

  void addListLiteral(void Function(ListLiteral) callback) {
    _visitor.onListLiteral = _wrapCallback(callback);
    _registry.addListLiteral(_rule, _visitor);
  }

  void addMethodDeclaration(void Function(MethodDeclaration) callback) {
    _visitor.onMethodDeclaration = _wrapCallback(callback);
    _registry.addMethodDeclaration(_rule, _visitor);
  }

  void addMethodInvocation(void Function(MethodInvocation) callback) {
    _visitor.onMethodInvocation = _wrapCallback(callback);
    _registry.addMethodInvocation(_rule, _visitor);
  }

  void addMixinDeclaration(void Function(MixinDeclaration) callback) {
    _visitor.onMixinDeclaration = _wrapCallback(callback);
    _registry.addMixinDeclaration(_rule, _visitor);
  }

  void addNamedExpression(void Function(NamedExpression) callback) {
    _visitor.onNamedExpression = _wrapCallback(callback);
    _registry.addNamedExpression(_rule, _visitor);
  }

  void addNamedType(void Function(NamedType) callback) {
    _visitor.onNamedType = _wrapCallback(callback);
    _registry.addNamedType(_rule, _visitor);
  }

  void addNullCheckPattern(void Function(NullCheckPattern) callback) {
    _visitor.onNullCheckPattern = _wrapCallback(callback);
    _registry.addNullCheckPattern(_rule, _visitor);
  }

  void addObjectPattern(void Function(ObjectPattern) callback) {
    _visitor.onObjectPattern = _wrapCallback(callback);
    _registry.addObjectPattern(_rule, _visitor);
  }

  void addPatternAssignment(void Function(PatternAssignment) callback) {
    _visitor.onPatternAssignment = _wrapCallback(callback);
    _registry.addPatternAssignment(_rule, _visitor);
  }

  void addPatternField(void Function(PatternField) callback) {
    _visitor.onPatternField = _wrapCallback(callback);
    _registry.addPatternField(_rule, _visitor);
  }

  void addPatternVariableDeclaration(
    void Function(PatternVariableDeclaration) callback,
  ) {
    _visitor.onPatternVariableDeclaration = _wrapCallback(callback);
    _registry.addPatternVariableDeclaration(_rule, _visitor);
  }

  void addPostfixExpression(void Function(PostfixExpression) callback) {
    _visitor.onPostfixExpression = _wrapCallback(callback);
    _registry.addPostfixExpression(_rule, _visitor);
  }

  void addPrefixExpression(void Function(PrefixExpression) callback) {
    _visitor.onPrefixExpression = _wrapCallback(callback);
    _registry.addPrefixExpression(_rule, _visitor);
  }

  void addPrefixedIdentifier(void Function(PrefixedIdentifier) callback) {
    _visitor.onPrefixedIdentifier = _wrapCallback(callback);
    _registry.addPrefixedIdentifier(_rule, _visitor);
  }

  void addPropertyAccess(void Function(PropertyAccess) callback) {
    _visitor.onPropertyAccess = _wrapCallback(callback);
    _registry.addPropertyAccess(_rule, _visitor);
  }

  void addRecordLiteral(void Function(RecordLiteral) callback) {
    _visitor.onRecordLiteral = _wrapCallback(callback);
    _registry.addRecordLiteral(_rule, _visitor);
  }

  void addRecordTypeAnnotation(void Function(RecordTypeAnnotation) callback) {
    _visitor.onRecordTypeAnnotation = _wrapCallback(callback);
    _registry.addRecordTypeAnnotation(_rule, _visitor);
  }

  void addReturnStatement(void Function(ReturnStatement) callback) {
    _visitor.onReturnStatement = _wrapCallback(callback);
    _registry.addReturnStatement(_rule, _visitor);
  }

  void addSetOrMapLiteral(void Function(SetOrMapLiteral) callback) {
    _visitor.onSetOrMapLiteral = _wrapCallback(callback);
    _registry.addSetOrMapLiteral(_rule, _visitor);
  }

  void addSimpleIdentifier(void Function(SimpleIdentifier) callback) {
    _visitor.onSimpleIdentifier = _wrapCallback(callback);
    _registry.addSimpleIdentifier(_rule, _visitor);
  }

  void addSimpleFormalParameter(void Function(SimpleFormalParameter) callback) {
    _visitor.onSimpleFormalParameter = _wrapCallback(callback);
    _registry.addSimpleFormalParameter(_rule, _visitor);
  }

  void addSimpleStringLiteral(void Function(SimpleStringLiteral) callback) {
    _visitor.onSimpleStringLiteral = _wrapCallback(callback);
    _registry.addSimpleStringLiteral(_rule, _visitor);
  }

  void addSpreadElement(void Function(SpreadElement) callback) {
    _visitor.onSpreadElement = _wrapCallback(callback);
    _registry.addSpreadElement(_rule, _visitor);
  }

  void addStringInterpolation(void Function(StringInterpolation) callback) {
    _visitor.onStringInterpolation = _wrapCallback(callback);
    _registry.addStringInterpolation(_rule, _visitor);
  }

  void addSwitchExpression(void Function(SwitchExpression) callback) {
    _visitor.onSwitchExpression = _wrapCallback(callback);
    _registry.addSwitchExpression(_rule, _visitor);
  }

  void addSwitchPatternCase(void Function(SwitchPatternCase) callback) {
    _visitor.onSwitchPatternCase = _wrapCallback(callback);
    _registry.addSwitchPatternCase(_rule, _visitor);
  }

  void addSwitchStatement(void Function(SwitchStatement) callback) {
    _visitor.onSwitchStatement = _wrapCallback(callback);
    _registry.addSwitchStatement(_rule, _visitor);
  }

  void addThrowExpression(void Function(ThrowExpression) callback) {
    _visitor.onThrowExpression = _wrapCallback(callback);
    _registry.addThrowExpression(_rule, _visitor);
  }

  void addTopLevelVariableDeclaration(
    void Function(TopLevelVariableDeclaration) callback,
  ) {
    _visitor.onTopLevelVariableDeclaration = _wrapCallback(callback);
    _registry.addTopLevelVariableDeclaration(_rule, _visitor);
  }

  void addTryStatement(void Function(TryStatement) callback) {
    _visitor.onTryStatement = _wrapCallback(callback);
    _registry.addTryStatement(_rule, _visitor);
  }

  void addTypeParameterList(void Function(TypeParameterList) callback) {
    _visitor.onTypeParameterList = _wrapCallback(callback);
    _registry.addTypeParameterList(_rule, _visitor);
  }

  void addVariableDeclaration(void Function(VariableDeclaration) callback) {
    _visitor.onVariableDeclaration = _wrapCallback(callback);
    _registry.addVariableDeclaration(_rule, _visitor);
  }

  void addVariableDeclarationList(
    void Function(VariableDeclarationList) callback,
  ) {
    _visitor.onVariableDeclarationList = _wrapCallback(callback);
    _registry.addVariableDeclarationList(_rule, _visitor);
  }

  void addVariableDeclarationStatement(
    void Function(VariableDeclarationStatement) callback,
  ) {
    _visitor.onVariableDeclarationStatement = _wrapCallback(callback);
    _registry.addVariableDeclarationStatement(_rule, _visitor);
  }

  void addWhileStatement(void Function(WhileStatement) callback) {
    _visitor.onWhileStatement = _wrapCallback(callback);
    _registry.addWhileStatement(_rule, _visitor);
  }

  void addYieldStatement(void Function(YieldStatement) callback) {
    _visitor.onYieldStatement = _wrapCallback(callback);
    _registry.addYieldStatement(_rule, _visitor);
  }

  // ===========================================================================
  // No-op stubs
  // ===========================================================================
  // These methods have no native analyzer equivalent. They are provided so
  // that rules ported from the custom_lint plugin still compile. The callbacks
  // are silently ignored.

  /// No-op: custom_lint's post-run callback has no native equivalent.
  void addPostRunCallback(void Function() callback) {}

  /// No-op: [FunctionBody] is not a visitable node in the native registry.
  ///
  /// Rules that need function-body analysis should register for
  /// [BlockFunctionBody] or [ExpressionFunctionBody] instead.
  void addFunctionBody(void Function(FunctionBody) callback) {}

  /// No-op: [FormalParameter] is not a visitable node in the native registry.
  ///
  /// Rules that need formal-parameter analysis should register for
  /// [SimpleFormalParameter] or [DefaultFormalParameter] instead.
  void addFormalParameter(void Function(FormalParameter) callback) {}
}
