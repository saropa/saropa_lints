// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/delete_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Remove self-assignment statement (e.g. x = x).
///
/// Matches [AvoidUnnecessaryReassignmentRule].
class RemoveUnnecessaryReassignmentFix extends DeleteNodeFix {
  RemoveUnnecessaryReassignmentFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeUnnecessaryReassignment',
    50,
    'Remove unnecessary self-assignment',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  AstNode? findTargetNode(AstNode node) {
    if (node is AssignmentExpression) {
      return node.thisOrAncestorOfType<ExpressionStatement>();
    }
    return node;
  }
}
