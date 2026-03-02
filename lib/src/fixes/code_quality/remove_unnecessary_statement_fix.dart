// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/delete_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Remove unnecessary statement.
class RemoveUnnecessaryStatementFix extends DeleteNodeFix {
  RemoveUnnecessaryStatementFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeUnnecessaryStatementFix',
    50,
    'Remove unnecessary statement',
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
