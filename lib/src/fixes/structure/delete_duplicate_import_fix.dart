// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/delete_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Remove duplicate import directive.
class DeleteDuplicateImportFix extends DeleteNodeFix {
  DeleteDuplicateImportFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.deleteDuplicateImportFix',
    50,
    'Remove duplicate import',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  AstNode? findTargetNode(AstNode node) {
    return node is ImportDirective
        ? node
        : node.thisOrAncestorOfType<ImportDirective>();
  }
}
