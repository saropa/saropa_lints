// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/delete_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Remove unnecessary override method.
class RemoveUnnecessaryOverrideFix extends DeleteNodeFix {
  RemoveUnnecessaryOverrideFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeUnnecessaryOverrideFix',
    50,
    'Remove unnecessary override',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  AstNode? findTargetNode(AstNode node) {
    return node is MethodDeclaration
        ? node
        : node.thisOrAncestorOfType<MethodDeclaration>();
  }
}
