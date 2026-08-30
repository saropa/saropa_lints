// ignore_for_file: depend_on_referenced_packages

/// Shared utilities for detecting early-exit guard patterns in AST blocks.
///
/// Many lint rules need to detect the "guard clause" pattern where an
/// if-statement early-exits (return/throw/break/continue) and all subsequent
/// statements in the block are therefore dominated by the negation of the
/// condition. This module provides reusable primitives so each rule doesn't
/// reimplement the same ancestor-walk logic independently.
///
/// Consumers supply a condition predicate to match their specific guard
/// shape (debug-mode check, mounted check, emptiness check, etc.).
library;

import 'package:analyzer/dart/ast/ast.dart';

/// Signature for a predicate that decides whether an if-statement's
/// condition constitutes a recognized guard for the calling rule.
typedef GuardConditionPredicate = bool Function(Expression condition);

/// True when [stmt] unconditionally exits the enclosing block.
///
/// Recognizes `return`, `throw`, `break`, `continue`, and blocks that
/// contain any of these as a direct child statement.
bool containsEarlyExit(Statement stmt) {
  if (stmt is ReturnStatement ||
      stmt is BreakStatement ||
      stmt is ContinueStatement) {
    return true;
  }
  // ThrowExpression is wrapped in an ExpressionStatement
  if (stmt is ExpressionStatement && stmt.expression is ThrowExpression) {
    return true;
  }
  // Recurse into braced blocks — any child that exits counts
  if (stmt is Block) {
    return stmt.statements.any(containsEarlyExit);
  }
  return false;
}

/// True when [stmt] ends with an early exit — the last statement in a
/// block (or the statement itself) is return/throw/break/continue.
///
/// More permissive than [containsEarlyExit] for multi-statement blocks
/// like `if (!cond) { cleanup(); return; }` where only the final
/// statement matters.
bool endsWithEarlyExit(Statement stmt) {
  if (stmt is ReturnStatement ||
      stmt is BreakStatement ||
      stmt is ContinueStatement) {
    return true;
  }
  if (stmt is ExpressionStatement && stmt.expression is ThrowExpression) {
    return true;
  }
  if (stmt is Block && stmt.statements.isNotEmpty) {
    return endsWithEarlyExit(stmt.statements.last);
  }
  return false;
}

/// Scan statements in [block] before [childStmt] for an if-statement
/// whose then-branch exits early and whose condition matches [predicate].
///
/// Returns `true` if a matching guard is found. The [requireNoElse] flag
/// (default `true`) rejects if-statements with an else branch, since
/// `if (cond) return; else doStuff();` is not a clean guard pattern.
///
/// The [exitTest] callback defaults to [containsEarlyExit] — pass
/// [endsWithEarlyExit] when multi-statement then-blocks should qualify.
bool findPrecedingGuardInBlock(
  Block block,
  AstNode childStmt, {
  required GuardConditionPredicate predicate,
  bool requireNoElse = true,
  bool Function(Statement) exitTest = containsEarlyExit,
}) {
  for (final Statement stmt in block.statements) {
    // Only check statements before the one containing the target
    if (identical(stmt, childStmt)) break;
    // Offset-based fallback when identity check doesn't match
    // (target may be nested deeper than the direct block child)
    if (stmt.offset >= childStmt.offset) break;

    if (stmt is! IfStatement) continue;
    if (requireNoElse && stmt.elseStatement != null) continue;
    if (!exitTest(stmt.thenStatement)) continue;
    if (predicate(stmt.expression)) return true;
  }
  return false;
}

/// Walk up from [node] through all ancestor [Block]s, checking each for
/// a preceding early-exit guard whose condition matches [predicate].
///
/// This is the ancestor-walking wrapper around [findPrecedingGuardInBlock]
/// for rules that need domination analysis across nested blocks (e.g. a
/// guard in the function body dominates code inside a nested try block).
///
/// When [stopAtClosureBoundary] is `true` (the default), the walk halts
/// at closure literals, function expressions, and local function
/// declarations — a guard in the outer scope does not dominate code inside
/// a nested closure whose execution is deferred. Set to `false` only for
/// compile-time constants (e.g. `kDebugMode`) where the closure can only
/// be created inside the guarded zone.
bool hasDominatingEarlyExitGuard(
  AstNode node, {
  required GuardConditionPredicate predicate,
  bool requireNoElse = true,
  bool stopAtClosureBoundary = true,
  bool Function(Statement) exitTest = containsEarlyExit,
}) {
  AstNode? child = node;
  AstNode? current = node.parent;
  while (current != null) {
    // Stop at closure/function boundaries when requested — a guard in
    // the outer scope doesn't dominate deferred-execution closures
    if (stopAtClosureBoundary && _isClosureBoundary(current)) break;

    if (current is Block) {
      if (findPrecedingGuardInBlock(
        current,
        child!,
        predicate: predicate,
        requireNoElse: requireNoElse,
        exitTest: exitTest,
      )) {
        return true;
      }
    }
    child = current;
    current = current.parent;
  }
  return false;
}

/// True when [node] is a closure or function boundary that defers execution.
///
/// Includes MethodDeclaration and FunctionDeclaration as defensive stops —
/// the enclosing function's body Block is always checked before the walk
/// reaches these, so same-function guards are found. These just prevent
/// the walk from escaping into class or file scope where guard statements
/// are impossible.
bool _isClosureBoundary(AstNode node) {
  return node is FunctionExpression ||
      node is MethodDeclaration ||
      node is FunctionDeclaration;
}
