/// The escape analysis behind `future_catch_all_utils.dart`: finds anything in
/// a `try` body or a handler that can still complete the enclosing async
/// function's future with an error. Split out to keep each file small.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'future_local_value_utils.dart';

/// Whether returning [expr] from an async function is certain not to hand the
/// caller a failing future. Unknown identifiers and calls could be futures, so
/// only values that are visibly not futures (or already awaited) qualify.
bool isSafeAsyncReturnValue(Expression? expr) {
  // A bare `return;` completes with null.
  if (expr == null) return true;
  if (expr is AwaitExpression || expr is Literal) return true;
  // A const object cannot be a pending or failed future.
  if (expr is InstanceCreationExpression) {
    return expr.keyword?.type == Keyword.CONST;
  }
  if (expr is ParenthesizedExpression) {
    return isSafeAsyncReturnValue(expr.expression);
  }
  if (expr is PrefixExpression) return isSafeAsyncReturnValue(expr.operand);
  // `await x ?? 'fallback'`: either side can become the result.
  if (expr is BinaryExpression) {
    return isSafeAsyncReturnValue(expr.leftOperand) &&
        isSafeAsyncReturnValue(expr.rightOperand);
  }
  if (expr is ConditionalExpression) {
    return isSafeAsyncReturnValue(expr.thenExpression) &&
        isSafeAsyncReturnValue(expr.elseExpression);
  }
  return false;
}

/// Sets [escapes] when a block holds something that can fail the future.
class FutureEscapeVisitor extends RecursiveAstVisitor<void> {
  /// Visits a `try` body ([isHandler] false) or a catch/finally block (true).
  FutureEscapeVisitor({required this.isHandler});

  /// True for `catch` / `finally` blocks, where `throw` and `await` are not
  /// covered by any enclosing handler.
  final bool isHandler;

  /// Latches to true on the first escape found.
  bool escapes = false;

  /// Depth of nested closures; their `return`s do not return from the method.
  int _closureDepth = 0;

  @override
  void visitFunctionExpression(FunctionExpression node) {
    _closureDepth++;
    super.visitFunctionExpression(node);
    _closureDepth--;
  }

  @override
  void visitReturnStatement(ReturnStatement node) {
    // A local typed as a plain value (`List<X> items`) is as safe as a literal;
    // any other identifier could be an un-awaited future.
    if (_closureDepth == 0 &&
        !isSafeAsyncReturnValue(node.expression) &&
        !returnsNonFutureLocal(node)) {
      escapes = true;
    }
    super.visitReturnStatement(node);
  }

  @override
  void visitThrowExpression(ThrowExpression node) {
    if (isHandler) escapes = true;
    super.visitThrowExpression(node);
  }

  @override
  void visitRethrowExpression(RethrowExpression node) {
    // `rethrow` is only legal in a handler, so it always escapes.
    escapes = true;
    super.visitRethrowExpression(node);
  }

  @override
  void visitAwaitExpression(AwaitExpression node) {
    if (isHandler) escapes = true;
    super.visitAwaitExpression(node);
  }

  @override
  void visitForStatement(ForStatement node) {
    // `await for` surfaces stream errors just like `await` does.
    if (isHandler && node.awaitKeyword != null) escapes = true;
    super.visitForStatement(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // `Error.throwWithStackTrace` is a rethrow spelled as a method call.
    if (node.methodName.name == 'throwWithStackTrace') escapes = true;
    _checkHandlerCall();
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    _checkHandlerCall();
    super.visitFunctionExpressionInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    // A non-const constructor runs arbitrary code; a const one cannot throw.
    if (node.keyword?.type != Keyword.CONST) _checkHandlerCall();
    super.visitInstanceCreationExpression(node);
  }

  /// Depth of statement-level calls being visited inside a handler.
  int _trustedCallDepth = 0;

  @override
  void visitExpressionStatement(ExpressionStatement node) {
    // A call used as a whole statement (`log(e, s);`, `debugPrint(...)`) is
    // trusted not to throw: that is the logging shape the exemption exists
    // for. A call whose result feeds an assignment, declaration or return is
    // not, because nothing marks it as a fire-and-forget side effect.
    final Expression expr = node.expression;
    final bool isTrusted =
        isHandler &&
        (expr is MethodInvocation || expr is FunctionExpressionInvocation);
    if (isTrusted) _trustedCallDepth++;
    super.visitExpressionStatement(node);
    if (isTrusted) _trustedCallDepth--;
  }

  /// Flags a call inside a handler that is not part of a trusted statement.
  void _checkHandlerCall() {
    if (isHandler && _trustedCallDepth == 0) escapes = true;
  }

  @override
  void visitPostfixExpression(PostfixExpression node) {
    // `x!` throws on null; `x++` on a field can run a throwing setter.
    if (isHandler) escapes = true;
    super.visitPostfixExpression(node);
  }

  @override
  void visitAsExpression(AsExpression node) {
    // `e as HttpException` throws for any other error type.
    if (isHandler) escapes = true;
    super.visitAsExpression(node);
  }

  @override
  void visitIndexExpression(IndexExpression node) {
    // `list[0]` / `map['k']!` can throw a RangeError or run a custom operator.
    if (isHandler) escapes = true;
    super.visitIndexExpression(node);
  }
}
