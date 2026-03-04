// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/delete_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Remove the unused assignment statement.
///
/// Matches [AvoidUnusedAssignmentRule]. Deletes the entire statement
/// so the variable keeps its previous value (or is assigned later).
class RemoveUnusedAssignmentFix extends DeleteNodeFix {
  RemoveUnusedAssignmentFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeUnusedAssignment',
    50,
    'Remove unused assignment',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  AstNode? findTargetNode(AstNode node) {
    return node.thisOrAncestorOfType<ExpressionStatement>();
  }
}
