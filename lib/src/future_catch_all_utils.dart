/// Decides whether a function body produces a future that can never complete
/// with an error. Used by `require_error_widget` so a `FutureBuilder` over a
/// self-handling future is not asked to render an unreachable error state.
///
/// Deliberately syntactic (no type resolution) and one-sided: every shape that
/// cannot be proven safe returns false, so the diagnostic is still reported.
library;

import 'package:analyzer/dart/ast/ast.dart';

import 'future_escape_visitor.dart';

/// Whether [body] is `async`, consists of exactly one `try` with a catch-all,
/// and lets no error out through any `return`, `throw` or handler.
bool bodyCannotCompleteWithError(FunctionBody body) {
  // Only a plain `async` block body wraps everything in the returned future;
  // `async*` produces a stream and a sync body can throw before any future.
  if (body is! BlockFunctionBody) return false;
  if (!body.isAsynchronous || body.isGenerator) return false;

  // A statement before or after the `try` could throw outside its protection.
  final NodeList<Statement> statements = body.block.statements;
  if (statements.length != 1) return false;
  final Statement only = statements.first;
  if (only is! TryStatement) return false;
  if (!only.catchClauses.any(_isCatchAll)) return false;

  // Inside the `try`, `await` and `throw` are caught; the one escape route is
  // returning a future that has not been awaited.
  final FutureEscapeVisitor tryVisitor = FutureEscapeVisitor(isHandler: false);
  only.body.accept(tryVisitor);
  if (tryVisitor.escapes) return false;

  // Handlers and `finally` have nothing protecting them, so they are held to
  // the stricter standard: only simple statements, no throw, no await, and no
  // expression that can throw synchronously (an error thrown there fails the
  // returned future just like an uncaught one).
  final List<Block> handlers = <Block>[
    for (final CatchClause clause in only.catchClauses) clause.body,
    ?only.finallyBlock,
  ];
  if (!handlers.every(_isSimpleStatement)) return false;
  final FutureEscapeVisitor handlerVisitor = FutureEscapeVisitor(
    isHandler: true,
  );
  for (final Block handler in handlers) {
    handler.accept(handlerVisitor);
  }
  return !handlerVisitor.escapes;
}

/// Whether [statement] is one of the plain shapes allowed in a handler:
/// blocks, `if`, expression statements, `return`, local declarations.
///
/// Loops, `switch`, nested `try`, labels and the rest are rejected outright:
/// proving they cannot throw is out of scope for a syntactic check.
bool _isSimpleStatement(Statement statement) {
  if (statement is Block) return statement.statements.every(_isSimpleStatement);
  if (statement is IfStatement) {
    final Statement? otherwise = statement.elseStatement;
    return _isSimpleStatement(statement.thenStatement) &&
        (otherwise == null || _isSimpleStatement(otherwise));
  }
  return statement is ExpressionStatement ||
      statement is ReturnStatement ||
      statement is VariableDeclarationStatement ||
      statement is EmptyStatement;
}

/// Whether [clause] catches everything: `catch (e)` with no `on` type, or
/// `on Object`. `on Exception` is not enough because `Error`s pass through.
bool _isCatchAll(CatchClause clause) {
  final TypeAnnotation? type = clause.exceptionType;
  if (type == null) return true;
  return type is NamedType &&
      type.importPrefix == null &&
      type.name.lexeme == 'Object';
}
