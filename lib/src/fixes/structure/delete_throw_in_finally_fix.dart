// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/delete_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Remove the throw statement in a finally block.
///
/// Matches [AvoidThrowInFinallyRule]. Deletes the entire statement
/// containing the throw so the original exception is preserved.
class DeleteThrowInFinallyFix extends DeleteNodeFix {
  DeleteThrowInFinallyFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.deleteThrowInFinally',
    50,
    'Remove throw from finally block',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  AstNode? findTargetNode(AstNode node) {
    return node.thisOrAncestorOfType<ExpressionStatement>();
  }
}
