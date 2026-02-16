// ignore_for_file: depend_on_referenced_packages

/// Visitor bridge that converts callback-based rule registration to the
/// native analyzer's visitor-based pattern.
///
/// Rules register callbacks via `context.addMethodInvocation((node) {...})`.
/// This visitor stores those callbacks and dispatches to them when the
/// analyzer walks the AST.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// A [SimpleAstVisitor] that dispatches to registered callbacks.
///
/// Each `visitXxx` method checks if a callback was registered for that
/// node type and invokes it. This bridges the gap between saropa_lints'
/// callback pattern and the native analyzer's visitor pattern.
class CompatVisitor extends SimpleAstVisitor<void> {
  void Function(AdjacentStrings)? onAdjacentStrings;
  void Function(Annotation)? onAnnotation;
  void Function(ArgumentList)? onArgumentList;
  void Function(AsExpression)? onAsExpression;
  void Function(AssertStatement)? onAssertStatement;
  void Function(AssignmentExpression)? onAssignmentExpression;
  void Function(AwaitExpression)? onAwaitExpression;
  void Function(BinaryExpression)? onBinaryExpression;
  void Function(Block)? onBlock;
  void Function(BlockFunctionBody)? onBlockFunctionBody;
  void Function(CascadeExpression)? onCascadeExpression;
  void Function(CatchClause)? onCatchClause;
  void Function(ClassDeclaration)? onClassDeclaration;
  void Function(CompilationUnit)? onCompilationUnit;
  void Function(ConditionalExpression)? onConditionalExpression;
  void Function(ConstructorDeclaration)? onConstructorDeclaration;
  void Function(ContinueStatement)? onContinueStatement;
  void Function(DeclaredVariablePattern)? onDeclaredVariablePattern;
  void Function(DefaultFormalParameter)? onDefaultFormalParameter;
  void Function(DoStatement)? onDoStatement;
  void Function(DoubleLiteral)? onDoubleLiteral;
  void Function(EnumConstantDeclaration)? onEnumConstantDeclaration;
  void Function(EnumDeclaration)? onEnumDeclaration;
  void Function(ExportDirective)? onExportDirective;
  void Function(ExpressionStatement)? onExpressionStatement;
  void Function(ExtensionDeclaration)? onExtensionDeclaration;
  void Function(ExtensionTypeDeclaration)? onExtensionTypeDeclaration;
  void Function(FieldDeclaration)? onFieldDeclaration;
  void Function(ForEachPartsWithDeclaration)? onForEachPartsWithDeclaration;
  void Function(ForElement)? onForElement;
  void Function(FormalParameterList)? onFormalParameterList;
  void Function(ForStatement)? onForStatement;
  void Function(FunctionDeclaration)? onFunctionDeclaration;
  void Function(FunctionDeclarationStatement)? onFunctionDeclarationStatement;
  void Function(FunctionExpression)? onFunctionExpression;
  void Function(FunctionExpressionInvocation)? onFunctionExpressionInvocation;
  void Function(GenericFunctionType)? onGenericFunctionType;
  void Function(GenericTypeAlias)? onGenericTypeAlias;
  void Function(IfElement)? onIfElement;
  void Function(IfStatement)? onIfStatement;
  void Function(ImportDirective)? onImportDirective;
  void Function(IndexExpression)? onIndexExpression;
  void Function(InstanceCreationExpression)? onInstanceCreationExpression;
  void Function(IntegerLiteral)? onIntegerLiteral;
  void Function(InterpolationExpression)? onInterpolationExpression;
  void Function(IsExpression)? onIsExpression;
  void Function(LibraryDirective)? onLibraryDirective;
  void Function(ListLiteral)? onListLiteral;
  void Function(MethodDeclaration)? onMethodDeclaration;
  void Function(MethodInvocation)? onMethodInvocation;
  void Function(MixinDeclaration)? onMixinDeclaration;
  void Function(NamedExpression)? onNamedExpression;
  void Function(NamedType)? onNamedType;
  void Function(NullCheckPattern)? onNullCheckPattern;
  void Function(ObjectPattern)? onObjectPattern;
  void Function(PatternAssignment)? onPatternAssignment;
  void Function(PatternField)? onPatternField;
  void Function(PatternVariableDeclaration)? onPatternVariableDeclaration;
  void Function(PostfixExpression)? onPostfixExpression;
  void Function(PrefixExpression)? onPrefixExpression;
  void Function(PrefixedIdentifier)? onPrefixedIdentifier;
  void Function(PropertyAccess)? onPropertyAccess;
  void Function(RecordLiteral)? onRecordLiteral;
  void Function(RecordTypeAnnotation)? onRecordTypeAnnotation;
  void Function(ReturnStatement)? onReturnStatement;
  void Function(SetOrMapLiteral)? onSetOrMapLiteral;
  void Function(SimpleIdentifier)? onSimpleIdentifier;
  void Function(SimpleFormalParameter)? onSimpleFormalParameter;
  void Function(SimpleStringLiteral)? onSimpleStringLiteral;
  void Function(SpreadElement)? onSpreadElement;
  void Function(StringInterpolation)? onStringInterpolation;
  void Function(SwitchExpression)? onSwitchExpression;
  void Function(SwitchPatternCase)? onSwitchPatternCase;
  void Function(SwitchStatement)? onSwitchStatement;
  void Function(ThrowExpression)? onThrowExpression;
  void Function(TopLevelVariableDeclaration)? onTopLevelVariableDeclaration;
  void Function(TryStatement)? onTryStatement;
  void Function(TypeParameterList)? onTypeParameterList;
  void Function(VariableDeclaration)? onVariableDeclaration;
  void Function(VariableDeclarationList)? onVariableDeclarationList;
  void Function(VariableDeclarationStatement)? onVariableDeclarationStatement;
  void Function(WhileStatement)? onWhileStatement;
  void Function(YieldStatement)? onYieldStatement;

  @override
  void visitAdjacentStrings(AdjacentStrings node) =>
      onAdjacentStrings?.call(node);
  @override
  void visitAnnotation(Annotation node) => onAnnotation?.call(node);
  @override
  void visitArgumentList(ArgumentList node) => onArgumentList?.call(node);
  @override
  void visitAsExpression(AsExpression node) => onAsExpression?.call(node);
  @override
  void visitAssertStatement(AssertStatement node) =>
      onAssertStatement?.call(node);
  @override
  void visitAssignmentExpression(AssignmentExpression node) =>
      onAssignmentExpression?.call(node);
  @override
  void visitAwaitExpression(AwaitExpression node) =>
      onAwaitExpression?.call(node);
  @override
  void visitBinaryExpression(BinaryExpression node) =>
      onBinaryExpression?.call(node);
  @override
  void visitBlock(Block node) => onBlock?.call(node);
  @override
  void visitBlockFunctionBody(BlockFunctionBody node) =>
      onBlockFunctionBody?.call(node);
  @override
  void visitCascadeExpression(CascadeExpression node) =>
      onCascadeExpression?.call(node);
  @override
  void visitCatchClause(CatchClause node) => onCatchClause?.call(node);
  @override
  void visitClassDeclaration(ClassDeclaration node) =>
      onClassDeclaration?.call(node);
  @override
  void visitCompilationUnit(CompilationUnit node) =>
      onCompilationUnit?.call(node);
  @override
  void visitConditionalExpression(ConditionalExpression node) =>
      onConditionalExpression?.call(node);
  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) =>
      onConstructorDeclaration?.call(node);
  @override
  void visitContinueStatement(ContinueStatement node) =>
      onContinueStatement?.call(node);
  @override
  void visitDeclaredVariablePattern(DeclaredVariablePattern node) =>
      onDeclaredVariablePattern?.call(node);
  @override
  void visitDefaultFormalParameter(DefaultFormalParameter node) =>
      onDefaultFormalParameter?.call(node);
  @override
  void visitDoStatement(DoStatement node) => onDoStatement?.call(node);
  @override
  void visitDoubleLiteral(DoubleLiteral node) => onDoubleLiteral?.call(node);
  @override
  void visitEnumConstantDeclaration(EnumConstantDeclaration node) =>
      onEnumConstantDeclaration?.call(node);
  @override
  void visitEnumDeclaration(EnumDeclaration node) =>
      onEnumDeclaration?.call(node);
  @override
  void visitExportDirective(ExportDirective node) =>
      onExportDirective?.call(node);
  @override
  void visitExpressionStatement(ExpressionStatement node) =>
      onExpressionStatement?.call(node);
  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) =>
      onExtensionDeclaration?.call(node);
  @override
  void visitExtensionTypeDeclaration(ExtensionTypeDeclaration node) =>
      onExtensionTypeDeclaration?.call(node);
  @override
  void visitFieldDeclaration(FieldDeclaration node) =>
      onFieldDeclaration?.call(node);
  @override
  void visitForEachPartsWithDeclaration(ForEachPartsWithDeclaration node) =>
      onForEachPartsWithDeclaration?.call(node);
  @override
  void visitForElement(ForElement node) => onForElement?.call(node);
  @override
  void visitFormalParameterList(FormalParameterList node) =>
      onFormalParameterList?.call(node);
  @override
  void visitForStatement(ForStatement node) => onForStatement?.call(node);
  @override
  void visitFunctionDeclaration(FunctionDeclaration node) =>
      onFunctionDeclaration?.call(node);
  @override
  void visitFunctionDeclarationStatement(FunctionDeclarationStatement node) =>
      onFunctionDeclarationStatement?.call(node);
  @override
  void visitFunctionExpression(FunctionExpression node) =>
      onFunctionExpression?.call(node);
  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) =>
      onFunctionExpressionInvocation?.call(node);
  @override
  void visitGenericFunctionType(GenericFunctionType node) =>
      onGenericFunctionType?.call(node);
  @override
  void visitGenericTypeAlias(GenericTypeAlias node) =>
      onGenericTypeAlias?.call(node);
  @override
  void visitIfElement(IfElement node) => onIfElement?.call(node);
  @override
  void visitIfStatement(IfStatement node) => onIfStatement?.call(node);
  @override
  void visitImportDirective(ImportDirective node) =>
      onImportDirective?.call(node);
  @override
  void visitIndexExpression(IndexExpression node) =>
      onIndexExpression?.call(node);
  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) =>
      onInstanceCreationExpression?.call(node);
  @override
  void visitIntegerLiteral(IntegerLiteral node) => onIntegerLiteral?.call(node);
  @override
  void visitInterpolationExpression(InterpolationExpression node) =>
      onInterpolationExpression?.call(node);
  @override
  void visitIsExpression(IsExpression node) => onIsExpression?.call(node);
  @override
  void visitLibraryDirective(LibraryDirective node) =>
      onLibraryDirective?.call(node);
  @override
  void visitListLiteral(ListLiteral node) => onListLiteral?.call(node);
  @override
  void visitMethodDeclaration(MethodDeclaration node) =>
      onMethodDeclaration?.call(node);
  @override
  void visitMethodInvocation(MethodInvocation node) =>
      onMethodInvocation?.call(node);
  @override
  void visitMixinDeclaration(MixinDeclaration node) =>
      onMixinDeclaration?.call(node);
  @override
  void visitNamedExpression(NamedExpression node) =>
      onNamedExpression?.call(node);
  @override
  void visitNamedType(NamedType node) => onNamedType?.call(node);
  @override
  void visitNullCheckPattern(NullCheckPattern node) =>
      onNullCheckPattern?.call(node);
  @override
  void visitObjectPattern(ObjectPattern node) => onObjectPattern?.call(node);
  @override
  void visitPatternAssignment(PatternAssignment node) =>
      onPatternAssignment?.call(node);
  @override
  void visitPatternField(PatternField node) => onPatternField?.call(node);
  @override
  void visitPatternVariableDeclaration(PatternVariableDeclaration node) =>
      onPatternVariableDeclaration?.call(node);
  @override
  void visitPostfixExpression(PostfixExpression node) =>
      onPostfixExpression?.call(node);
  @override
  void visitPrefixExpression(PrefixExpression node) =>
      onPrefixExpression?.call(node);
  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) =>
      onPrefixedIdentifier?.call(node);
  @override
  void visitPropertyAccess(PropertyAccess node) => onPropertyAccess?.call(node);
  @override
  void visitRecordLiteral(RecordLiteral node) => onRecordLiteral?.call(node);
  @override
  void visitRecordTypeAnnotation(RecordTypeAnnotation node) =>
      onRecordTypeAnnotation?.call(node);
  @override
  void visitReturnStatement(ReturnStatement node) =>
      onReturnStatement?.call(node);
  @override
  void visitSetOrMapLiteral(SetOrMapLiteral node) =>
      onSetOrMapLiteral?.call(node);
  @override
  void visitSimpleIdentifier(SimpleIdentifier node) =>
      onSimpleIdentifier?.call(node);
  @override
  void visitSimpleFormalParameter(SimpleFormalParameter node) =>
      onSimpleFormalParameter?.call(node);
  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) =>
      onSimpleStringLiteral?.call(node);
  @override
  void visitSpreadElement(SpreadElement node) => onSpreadElement?.call(node);
  @override
  void visitStringInterpolation(StringInterpolation node) =>
      onStringInterpolation?.call(node);
  @override
  void visitSwitchExpression(SwitchExpression node) =>
      onSwitchExpression?.call(node);
  @override
  void visitSwitchPatternCase(SwitchPatternCase node) =>
      onSwitchPatternCase?.call(node);
  @override
  void visitSwitchStatement(SwitchStatement node) =>
      onSwitchStatement?.call(node);
  @override
  void visitThrowExpression(ThrowExpression node) =>
      onThrowExpression?.call(node);
  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) =>
      onTopLevelVariableDeclaration?.call(node);
  @override
  void visitTryStatement(TryStatement node) => onTryStatement?.call(node);
  @override
  void visitTypeParameterList(TypeParameterList node) =>
      onTypeParameterList?.call(node);
  @override
  void visitVariableDeclaration(VariableDeclaration node) =>
      onVariableDeclaration?.call(node);
  @override
  void visitVariableDeclarationList(VariableDeclarationList node) =>
      onVariableDeclarationList?.call(node);
  @override
  void visitVariableDeclarationStatement(VariableDeclarationStatement node) =>
      onVariableDeclarationStatement?.call(node);
  @override
  void visitWhileStatement(WhileStatement node) => onWhileStatement?.call(node);
  @override
  void visitYieldStatement(YieldStatement node) => onYieldStatement?.call(node);
}
