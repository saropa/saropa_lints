// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/delete_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Remove unknown pragma annotation.
class DeleteUnknownPragmaFix extends DeleteNodeFix {
  DeleteUnknownPragmaFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.deleteUnknownPragmaFix',
    50,
    'Remove unknown pragma annotation',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  AstNode? findTargetNode(AstNode node) {
    return node is Annotation ? node : node.thisOrAncestorOfType<Annotation>();
  }
}
