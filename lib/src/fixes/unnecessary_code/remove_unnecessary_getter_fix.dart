// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/delete_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Remove unnecessary getter (getter that only returns a final field).
class RemoveUnnecessaryGetterFix extends DeleteNodeFix {
  RemoveUnnecessaryGetterFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeUnnecessaryGetterFix',
    50,
    'Remove unnecessary getter',
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
