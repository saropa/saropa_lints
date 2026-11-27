/// Scope helpers for the `require_error_widget` future tracing: which class a
/// node sits in, whether a local shadows a member name, and every value
/// written to a field or top-level variable in the unit.
///
/// Split from `future_source_utils.dart` to keep each file small. All checks
/// are name-based and err toward "unknown", which keeps the diagnostic.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'analyzer_compat.dart';

/// The class-like declaration around [node], or null at top level.
///
/// Enums, extensions and extension types are returned too (not only classes
/// and mixins): a call inside one must not be traced to a same-named
/// top-level function, because the member it really calls is the local one.
CompilationUnitMember? containerOf(AstNode node) =>
    node.thisOrAncestorMatching<CompilationUnitMember>(
      (AstNode n) =>
          n is ClassDeclaration ||
          n is MixinDeclaration ||
          n is EnumDeclaration ||
          n is ExtensionDeclaration ||
          n is ExtensionTypeDeclaration,
    );

/// Whether [container] is a type the tracing does not model (enum, extension,
/// extension type). Callers give up instead of guessing.
bool isUntracedContainer(CompilationUnitMember? container) =>
    container != null &&
    container is! ClassDeclaration &&
    container is! MixinDeclaration;

/// Members of a class or mixin; empty for anything else.
List<ClassMember> membersOf(CompilationUnitMember? container) {
  if (container is ClassDeclaration) return container.bodyMembers;
  if (container is MixinDeclaration) return container.bodyMembers;
  return const <ClassMember>[];
}

/// Whether [list] declares a variable called [name].
bool declaresVariable(VariableDeclarationList list, String name) =>
    list.variables.any((VariableDeclaration v) => v.name.lexeme == name);

/// The name read by `x` or `this.x`; null for every other expression shape
/// (`widget.future`, `controller.future`, ...), which cannot be traced.
String? tracedVariableName(Expression expr) {
  if (expr is SimpleIdentifier) return expr.name;
  if (expr is PropertyAccess && expr.target is ThisExpression) {
    return expr.propertyName.name;
  }
  return null;
}

/// Whether a parameter or local named [name] exists in the member around
/// [node]. Checked across the whole member (not by exact scope) on purpose:
/// over-detecting only keeps the diagnostic.
bool isShadowedLocally(AstNode node, String name) {
  final AstNode? member = node.thisOrAncestorMatching(
    (AstNode n) =>
        n is MethodDeclaration ||
        n is ConstructorDeclaration ||
        (n is FunctionDeclaration && n.parent is CompilationUnit),
  );
  if (member == null) return false;
  final _LocalNameFinder finder = _LocalNameFinder(name);
  member.visitChildren(finder);
  return finder.found;
}

/// Finds a parameter, local variable, local function or pattern binding.
class _LocalNameFinder extends RecursiveAstVisitor<void> {
  _LocalNameFinder(this.name);

  /// The member name that a local declaration would shadow.
  final String name;

  /// Latches to true on the first matching declaration.
  bool found = false;

  /// Records a match for any declaring token.
  void _check(Token? token) {
    if (token?.lexeme == name) found = true;
  }

  @override
  void visitRegularFormalParameter(RegularFormalParameter node) {
    _check(node.name);
    super.visitRegularFormalParameter(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    _check(node.name);
    super.visitVariableDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _check(node.name);
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitDeclaredIdentifier(DeclaredIdentifier node) {
    _check(node.name);
    super.visitDeclaredIdentifier(node);
  }

  @override
  void visitDeclaredVariablePattern(DeclaredVariablePattern node) {
    _check(node.name);
    super.visitDeclaredVariablePattern(node);
  }
}

/// Gathers every value written to the variable [name] anywhere in the unit.
class FutureSourceCollector extends RecursiveAstVisitor<void> {
  /// Collects writes to [name]; [owner] is the declaring class, or null for a
  /// top-level variable.
  FutureSourceCollector(this.name, this.owner);

  /// The field or top-level variable being traced.
  final String name;

  /// Class declaring the field, or null for a top-level variable.
  final CompilationUnitMember? owner;

  /// Right-hand sides of the writes that target the variable.
  final List<Expression> sources = <Expression>[];

  /// Set when a write exists whose value or target cannot be determined.
  bool hasUnknownSource = false;

  /// Whether an unqualified write at [node] belongs to a different class that
  /// declares its own field of the same name (common for `_future`).
  bool _isOtherClassField(AstNode node) {
    final CompilationUnitMember? here = containerOf(node);
    if (here == owner) return false;
    return membersOf(here).any(
      (ClassMember m) =>
          m is FieldDeclaration && declaresVariable(m.fields, name),
    );
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final Expression lhs = node.leftHandSide;
    final bool isBare = tracedVariableName(lhs) == name;
    // `other._future = x`: the receiver's type is unknown without resolution.
    final bool isQualified =
        (lhs is PrefixedIdentifier && lhs.identifier.name == name) ||
        (lhs is PropertyAccess &&
            lhs.target is! ThisExpression &&
            lhs.propertyName.name == name);
    if (isQualified) hasUnknownSource = true;
    if (isBare && !_isOtherClassField(node)) {
      final TokenType op = node.operator.type;
      // A write from a subclass or unrelated scope cannot be traced safely.
      final bool isOwnScope = owner == null || containerOf(node) == owner;
      if (isOwnScope &&
          (op == TokenType.EQ || op == TokenType.QUESTION_QUESTION_EQ)) {
        sources.add(node.rightHandSide);
      } else {
        hasUnknownSource = true;
      }
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitConstructorFieldInitializer(ConstructorFieldInitializer node) {
    if (node.fieldName.name == name && containerOf(node) == owner) {
      sources.add(node.expression);
    }
    super.visitConstructorFieldInitializer(node);
  }

  @override
  void visitFieldFormalParameter(FieldFormalParameter node) {
    // `this._future` takes the value from the caller.
    if (node.name.lexeme == name && containerOf(node) == owner) {
      hasUnknownSource = true;
    }
    super.visitFieldFormalParameter(node);
  }

  @override
  void visitAssignedVariablePattern(AssignedVariablePattern node) {
    // `(_future, _) = record`: the value is not visible as an expression.
    if (node.name.lexeme == name) hasUnknownSource = true;
    super.visitAssignedVariablePattern(node);
  }
}
