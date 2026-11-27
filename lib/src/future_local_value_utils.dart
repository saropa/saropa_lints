/// Recognizes `return someLocal;` where the local's written type rules out a
/// future, for the `require_error_widget` escape analysis.
///
/// Without it a self-handling loader that names its result before returning it
/// (`final List<Item> items = await load(); return items;`) was still reported.
library;

import 'package:analyzer/dart/ast/ast.dart';

/// Core types a `Future` can never be an instance of. Deliberately a closed
/// list: `Object`, `dynamic`, `var`, aliases and user types could hold one.
const Set<String> _nonFutureTypes = <String>{
  'bool',
  'double',
  'int',
  'List',
  'Map',
  'num',
  'Set',
  'String',
};

/// Whether [node] returns a local variable whose explicit type cannot be a
/// future. The declaration must precede the return in an enclosing block.
bool returnsNonFutureLocal(ReturnStatement node) {
  final Expression? value = node.expression;
  if (value is! SimpleIdentifier) return false;

  AstNode child = node;
  AstNode? parent = node.parent;
  while (parent != null) {
    if (parent is Block) {
      // The nearest declaration of the name is the one the return reads.
      for (final Statement statement in parent.statements) {
        if (identical(statement, child)) break;
        if (statement is! VariableDeclarationStatement) continue;
        final VariableDeclarationList list = statement.variables;
        for (final VariableDeclaration variable in list.variables) {
          if (variable.name.lexeme == value.name) {
            return _isNonFuture(list, variable);
          }
        }
      }
    } else if (!_isTransparent(parent)) {
      // Loops, patterns, closures and the like can rebind the name, so an
      // outer declaration would prove nothing: give up and keep reporting.
      return false;
    }
    child = parent;
    parent = parent.parent;
  }
  return false;
}

/// Whether [node] introduces no names between the return and its declaration.
bool _isTransparent(AstNode node) =>
    node is IfStatement && node.caseClause == null;

/// Whether [variable] is initialized and typed as one of the safe core types.
bool _isNonFuture(VariableDeclarationList list, VariableDeclaration variable) {
  // Reading an unassigned `late` local throws, which would fail the future.
  if (list.lateKeyword != null || variable.initializer == null) return false;
  final TypeAnnotation? type = list.type;
  return type is NamedType &&
      type.importPrefix == null &&
      _nonFutureTypes.contains(type.name.lexeme);
}
