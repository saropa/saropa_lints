// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../common/delete_node_fix.dart';
import '../../../native/saropa_fix.dart';

/// Quick fix: Remove add() call from BLoC constructor.
class RemoveBlocEventInConstructorFix extends DeleteNodeFix {
  RemoveBlocEventInConstructorFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeBlocEventInConstructorFix',
    50,
    'Remove add() call from constructor',
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
