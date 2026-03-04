// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/delete_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Remove the statement containing a self-assignment (e.g. x = x).
///
/// Matches [AvoidSelfAssignmentRule].
class RemoveSelfAssignmentFix extends DeleteNodeFix {
  RemoveSelfAssignmentFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeSelfAssignment',
    50,
    'Remove self-assignment statement',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  AstNode? findTargetNode(AstNode node) {
    return node is ExpressionStatement
        ? node
        : node.thisOrAncestorOfType<ExpressionStatement>();
  }
}
