/// Syntactic scope helpers: does an AST node introduce a local name?
///
/// Rules that resolve a bare identifier by walking outward through the AST
/// (to find "the" declaration of `items` or `match`) must stop at every
/// construct that can bind that name. Missing one makes the walk skip past
/// the real (inner) binding and land on an unrelated outer declaration with
/// the same name, which is how a loop variable, a catch parameter or a
/// pattern binding used to be mistaken for a same-named top-level constant
/// or an earlier regex match. Keeping the list of binding constructs here
/// gives every such walk the same, complete answer.
///
/// Name-based on purpose: it behaves identically on the resolved analyzer
/// run and on the unresolved `scan` CLI, where elements are unavailable.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// True when [node] binds [name] for code nested inside it: a function,
/// method or constructor parameter, a `for` loop variable (statement or
/// collection element, declared or pattern), a `catch` parameter, or a
/// pattern variable of an if-case, switch case or switch-expression case.
///
/// Conservative by design: a binding whose scope covers only part of [node]
/// (an if-case variable is not visible in the `else` branch) still counts,
/// because callers treat "bound" as "unknown value" and keep their lint.
bool bindsNameAt(AstNode node, String name) {
  final FormalParameterList? parameters = switch (node) {
    FunctionExpression() => node.parameters,
    MethodDeclaration() => node.parameters,
    ConstructorDeclaration() => node.parameters,
    _ => null,
  };
  if (parameters != null) {
    return parameters.parameters.any((p) => p.name?.lexeme == name);
  }
  return switch (node) {
    ForStatement() => _loopPartsBind(node.forLoopParts, name),
    ForElement() => _loopPartsBind(node.forLoopParts, name),
    CatchClause() =>
      node.exceptionParameter?.name.lexeme == name ||
          node.stackTraceParameter?.name.lexeme == name,
    IfStatement() => _patternBinds(node.caseClause?.guardedPattern, name),
    IfElement() => _patternBinds(node.caseClause?.guardedPattern, name),
    SwitchPatternCase() => _patternBinds(node.guardedPattern, name),
    SwitchExpressionCase() => _patternBinds(node.guardedPattern, name),
    _ => false,
  };
}

/// True when [statement], as an earlier statement of an enclosing block,
/// declares [name] in a form other than a plain `VariableDeclarationStatement`
/// (callers inspect those themselves, since they need the initializer):
/// a pattern declaration (`final (a, b) = ...;`) or a local function.
bool statementBindsName(Statement statement, String name) {
  if (statement is PatternVariableDeclarationStatement) {
    return patternDeclaresName(statement.declaration.pattern, name);
  }
  if (statement is FunctionDeclarationStatement) {
    return statement.functionDeclaration.name.lexeme == name;
  }
  return false;
}

/// True when [pattern] declares a variable named [name] at any depth
/// (`final x`, `[final x, _]`, `Point(:final x)`, `(x: var x)`).
bool patternDeclaresName(DartPattern pattern, String name) {
  final _DeclaredNameFinder finder = _DeclaredNameFinder(name);
  pattern.accept(finder);
  return finder.found;
}

/// Loop variables introduced by any of the four `for` header forms. The
/// `ForEachPartsWithIdentifier` / `ForPartsWithExpression` forms assign an
/// existing variable and bind nothing new, so they return false.
bool _loopPartsBind(ForLoopParts parts, String name) {
  return switch (parts) {
    ForEachPartsWithDeclaration() => parts.loopVariable.name.lexeme == name,
    ForPartsWithDeclarations() => parts.variables.variables.any(
      (v) => v.name.lexeme == name,
    ),
    ForEachPartsWithPattern() => patternDeclaresName(parts.pattern, name),
    ForPartsWithPattern() => patternDeclaresName(parts.variables.pattern, name),
    _ => false,
  };
}

/// Null-tolerant [patternDeclaresName] for an optional case clause.
bool _patternBinds(GuardedPattern? guarded, String name) =>
    guarded != null && patternDeclaresName(guarded.pattern, name);

/// Finds a `DeclaredVariablePattern` named [name] inside a pattern tree.
class _DeclaredNameFinder extends RecursiveAstVisitor<void> {
  _DeclaredNameFinder(this.name);

  final String name;
  bool found = false;

  @override
  void visitDeclaredVariablePattern(DeclaredVariablePattern node) {
    if (node.name.lexeme == name) found = true;
    super.visitDeclaredVariablePattern(node);
  }
}
