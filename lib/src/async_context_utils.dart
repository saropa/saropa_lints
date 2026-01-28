// ignore_for_file: depend_on_referenced_packages

/// Shared utilities for async/await and mounted check analysis.
///
/// These utilities are used by multiple rules that detect context usage
/// after async gaps without proper mounted checks:
/// - [AvoidContextAcrossAsyncRule]
/// - [UseSetStateSynchronouslyRule]
/// - [AvoidScaffoldMessengerAfterAwaitRule]
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Checks if an AST node contains any await expressions.
///
/// Skips nested function expressions since they have their own async scope.
/// Returns true if at least one await is found in the subtree.
bool containsAwait(AstNode node) {
  bool found = false;
  node.visitChildren(AwaitFinder((_) => found = true));
  return found;
}

/// Checks if expression is `mounted`, `this.mounted`, or `context.mounted`.
///
/// Uses proper AST type checking instead of string matching to avoid
/// false positives on variables like "isMounted" or "mountedCount".
///
/// Also handles compound `&&` conditions where any operand checks mounted,
/// e.g., `mounted && context.mounted` or `someCondition && mounted`.
bool checksMounted(Expression expr) {
  // Direct `mounted` identifier
  if (expr is SimpleIdentifier && expr.name == 'mounted') return true;

  // `this.mounted` or `context.mounted` - prefixed access
  if (expr is PrefixedIdentifier && expr.identifier.name == 'mounted') {
    return true;
  }

  // `mounted == true` or `true == mounted`
  if (expr is BinaryExpression && expr.operator.type == TokenType.EQ_EQ) {
    final left = expr.leftOperand;
    final right = expr.rightOperand;
    if (_isTrueLiteral(left) && checksMounted(right)) return true;
    if (_isTrueLiteral(right) && checksMounted(left)) return true;
  }

  // Compound `&&` conditions: `mounted && otherCondition` or vice versa
  // If any part of an && chain checks mounted, the then-branch is protected
  if (expr is BinaryExpression &&
      expr.operator.type == TokenType.AMPERSAND_AMPERSAND) {
    return checksMounted(expr.leftOperand) || checksMounted(expr.rightOperand);
  }

  return false;
}

/// Checks if expression is `!mounted`, `!this.mounted`, or `!context.mounted`.
///
/// Also handles `mounted == false` and `false == mounted` patterns.
bool checksNotMounted(Expression expr) {
  // `!mounted` - prefix negation
  if (expr is PrefixExpression && expr.operator.type == TokenType.BANG) {
    return checksMounted(expr.operand);
  }

  // `mounted == false` or `false == mounted`
  if (expr is BinaryExpression && expr.operator.type == TokenType.EQ_EQ) {
    final left = expr.leftOperand;
    final right = expr.rightOperand;
    if (_isFalseLiteral(left) && checksMounted(right)) return true;
    if (_isFalseLiteral(right) && checksMounted(left)) return true;
  }

  return false;
}

/// Checks if statement is an early-exit mounted guard: `if (!mounted) return;`
///
/// This pattern protects all subsequent code in the same block from using
/// an invalid context. Recognized patterns:
/// - `if (!mounted) return;`
/// - `if (!mounted) throw ...;`
/// - `if (mounted == false) return;`
bool isNegatedMountedGuard(Statement stmt) {
  if (stmt is! IfStatement) return false;

  // Must be a negated mounted check
  if (!checksNotMounted(stmt.expression)) return false;

  // Then branch must contain early exit (return or throw)
  return containsEarlyExit(stmt.thenStatement);
}

/// Checks if statement is a positive mounted guard: `if (mounted) { ... }`
///
/// Context usage inside the then-block is safe. The else-block is NOT safe.
bool isPositiveMountedGuard(Statement stmt) {
  if (stmt is! IfStatement) return false;
  return checksMounted(stmt.expression);
}

/// Checks if the node is inside the then-branch of an if-statement.
///
/// Used to verify context usage is protected by `if (mounted) { ... }`.
bool isInThenBranch(AstNode node, IfStatement ifStmt) {
  AstNode? current = node;
  while (current != null && current != ifStmt) {
    if (current == ifStmt.thenStatement) return true;
    if (current == ifStmt.elseStatement) return false;
    current = current.parent;
  }
  return false;
}

/// Checks if the node has an ancestor if-statement that checks mounted.
///
/// Stops at function boundaries since mounted checks only apply within
/// the same function scope.
bool hasAncestorMountedCheck(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    if (current is IfStatement) {
      if (checksMounted(current.expression)) {
        // Verify node is in THEN branch (protected), not ELSE branch
        if (isInThenBranch(node, current)) return true;
      }
    }
    // Stop at function boundaries
    if (current is FunctionExpression || current is MethodDeclaration) break;
    current = current.parent;
  }
  return false;
}

// ---------------------------------------------------------------------------
// Early Exit Detection
// ---------------------------------------------------------------------------

/// Checks if a statement contains an early exit (return or throw).
///
/// Used by mounted guard detection to verify that negated guards
/// (`if (!mounted) return;`) actually exit the function.
bool containsEarlyExit(Statement stmt) {
  if (stmt is ReturnStatement) return true;
  if (stmt is ExpressionStatement && stmt.expression is ThrowExpression) {
    return true;
  }
  // Handle block with single return/throw
  if (stmt is Block && stmt.statements.length == 1) {
    return containsEarlyExit(stmt.statements.first);
  }
  return false;
}

// ---------------------------------------------------------------------------
// BuildContext Parameter Helpers
// ---------------------------------------------------------------------------

/// Checks if a formal parameter is a BuildContext type.
///
/// Handles both simple parameters and default parameters (with default values).
/// Returns true for `BuildContext`, `BuildContext?`, or any type containing
/// `BuildContext` (e.g., generic types).
bool isBuildContextParam(FormalParameter param) {
  if (param is SimpleFormalParameter) {
    final typeSource = param.type?.toSource();
    if (typeSource == null) return false;
    return typeSource == 'BuildContext' ||
        typeSource == 'BuildContext?' ||
        typeSource.contains('BuildContext');
  }
  if (param is DefaultFormalParameter) {
    return isBuildContextParam(param.parameter);
  }
  return false;
}

/// Gets the parameter name if it's a BuildContext type, null otherwise.
///
/// Useful for tracking context parameter names in static methods where
/// the parameter might not be named 'context'.
String? getBuildContextParamName(FormalParameter param) {
  if (param is SimpleFormalParameter) {
    final typeSource = param.type?.toSource();
    if (typeSource == null) return null;
    if (typeSource == 'BuildContext' ||
        typeSource == 'BuildContext?' ||
        typeSource.contains('BuildContext')) {
      return param.name?.lexeme;
    }
  }
  if (param is DefaultFormalParameter) {
    return getBuildContextParamName(param.parameter);
  }
  return null;
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

bool _isTrueLiteral(Expression expr) =>
    expr is BooleanLiteral && expr.value == true;

bool _isFalseLiteral(Expression expr) =>
    expr is BooleanLiteral && expr.value == false;

// ---------------------------------------------------------------------------
// Visitor classes
// ---------------------------------------------------------------------------

/// Visitor that finds await expressions, skipping nested functions.
///
/// Nested function expressions have their own async scope and should not
/// be considered part of the parent function's await tracking.
class AwaitFinder extends RecursiveAstVisitor<void> {
  AwaitFinder(this.onFound);
  final void Function(AwaitExpression) onFound;

  @override
  void visitAwaitExpression(AwaitExpression node) {
    onFound(node);
    super.visitAwaitExpression(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Don't descend into nested functions - they have their own async scope
    return;
  }
}

/// Visitor that finds context usage and reports it.
///
/// Skips nested function expressions since callbacks have their own
/// valid context scope (e.g., builder callbacks).
class ContextUsageFinder extends RecursiveAstVisitor<void> {
  ContextUsageFinder({required this.onContextFound});

  final void Function(SimpleIdentifier) onContextFound;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == 'context') {
      // Skip if this is a named argument label, not a variable reference
      // e.g., in `foo(context: value)`, the 'context' label is not a usage
      if (node.parent is Label) {
        super.visitSimpleIdentifier(node);
        return;
      }

      // Skip if part of a mounted check (context.mounted is safe to access)
      final parent = node.parent;
      if (parent is PrefixedIdentifier && parent.identifier.name == 'mounted') {
        super.visitSimpleIdentifier(node);
        return;
      }
      // Skip if part of nullable mounted check (context?.mounted is safe)
      if (parent is PropertyAccess && parent.propertyName.name == 'mounted') {
        super.visitSimpleIdentifier(node);
        return;
      }

      // Skip if inside a mounted guard: if (context.mounted) { ... }
      // This handles nested guards inside other statements, e.g.:
      //   if (someCondition) { if (context.mounted) context.doThing(); }
      if (hasAncestorMountedCheck(node)) {
        super.visitSimpleIdentifier(node);
        return;
      }

      // Skip if in then-branch of mounted-guarded ternary:
      // `context.mounted ? context : null` is safe
      if (_isInMountedGuardedTernary(node)) {
        super.visitSimpleIdentifier(node);
        return;
      }

      onContextFound(node);
    }
    super.visitSimpleIdentifier(node);
  }

  /// Checks if node is in the then-branch of a mounted-guarded ternary.
  ///
  /// Pattern: `context.mounted ? context : null`
  /// The context in the then-expression is safe because it's guarded.
  bool _isInMountedGuardedTernary(SimpleIdentifier node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is ConditionalExpression) {
        // Check if this node is in the then-expression
        if (_isDescendantOf(node, current.thenExpression)) {
          // Check if condition is a mounted check
          if (_isMountedCheck(current.condition)) {
            return true;
          }
        }
        return false;
      }
      // Continue searching up the AST tree (don't stop at statement boundaries)
      // This allows detection in catch blocks and other complex expressions
      current = current.parent;
    }
    return false;
  }

  /// Checks if expression is context.mounted or mounted.
  ///
  /// Recognizes patterns:
  /// - `context.mounted` (PrefixedIdentifier)
  /// - `mounted` (SimpleIdentifier in State class)
  /// - `context?.mounted ?? false` (nullable-safe pattern)
  bool _isMountedCheck(Expression expr) {
    // context.mounted
    if (expr is PrefixedIdentifier && expr.identifier.name == 'mounted') {
      return true;
    }
    // mounted (bare identifier in State class)
    if (expr is SimpleIdentifier && expr.name == 'mounted') {
      return true;
    }
    // context?.mounted ?? false (nullable-safe pattern)
    if (expr is BinaryExpression &&
        expr.operator.type == TokenType.QUESTION_QUESTION) {
      final left = expr.leftOperand;
      // Check if left side is context?.mounted (PropertyAccess)
      if (left is PropertyAccess) {
        if (left.propertyName.name == 'mounted' && left.isNullAware) {
          return true;
        }
      }
    }
    return false;
  }

  /// Checks if child is a descendant of parent.
  bool _isDescendantOf(AstNode child, AstNode parent) {
    AstNode? current = child;
    while (current != null) {
      if (current == parent) return true;
      current = current.parent;
    }
    return false;
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Don't descend into callbacks - they have their own valid context scope
    return;
  }
}

// ---------------------------------------------------------------------------
// Isolate/Compute Detection
// ---------------------------------------------------------------------------

/// Checks if the node is inside a `compute()` or `Isolate.run()` call.
///
/// Used by performance rules to skip warnings when heavy operations are
/// already offloaded to a background isolate.
///
/// Recognizes:
/// - `compute(fn, data)` - Flutter's compute helper
/// - `Isolate.run(() => ...)` - Direct isolate usage
///
/// Returns true if the node is inside either construct.
bool isInsideIsolate(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    if (current is MethodInvocation) {
      final String name = current.methodName.name;
      if (name == 'compute') {
        // compute() is always safe (no target)
        if (current.target == null) return true;
      } else if (name == 'run') {
        // Must be Isolate.run(), not any other .run()
        final Expression? target = current.target;
        if (target is SimpleIdentifier && target.name == 'Isolate') {
          return true;
        }
      }
    }
    current = current.parent;
  }
  return false;
}

/// Checks if the node is inside an async function or method.
///
/// Used to detect if heavy operations are in async context (likely handling
/// network responses or other IO-bound data).
///
/// Returns true if the containing function/method is marked `async`.
bool isInAsyncContext(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    if (current is FunctionDeclaration) {
      return current.functionExpression.body.isAsynchronous;
    }
    if (current is MethodDeclaration) {
      return current.body.isAsynchronous;
    }
    if (current is FunctionExpression) {
      return current.body.isAsynchronous;
    }
    current = current.parent;
  }
  return false;
}

/// Visitor that finds setState calls not protected by mounted checks.
///
/// Traverses the AST and tracks whether we're inside an `if (mounted)` block.
class SetStateWithMountedCheckFinder extends RecursiveAstVisitor<void> {
  SetStateWithMountedCheckFinder(this.onUnprotectedSetState);

  final void Function(MethodInvocation) onUnprotectedSetState;

  @override
  void visitIfStatement(IfStatement node) {
    // Positive mounted check: if (mounted) { ... }
    // Don't visit then branch - setState inside is protected
    if (checksMounted(node.expression)) {
      node.elseStatement?.accept(this);
      return;
    }

    // Negated mounted check: if (!mounted) return;
    // Code AFTER this statement is protected, but still check then branch
    if (checksNotMounted(node.expression)) {
      super.visitIfStatement(node);
      return;
    }

    super.visitIfStatement(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'setState') {
      if (!hasAncestorMountedCheck(node)) {
        onUnprotectedSetState(node);
      }
    }
    super.visitMethodInvocation(node);
  }
}
