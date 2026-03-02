// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/delete_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Remove duplicate export directive.
class DeleteDuplicateExportFix extends DeleteNodeFix {
  DeleteDuplicateExportFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.deleteDuplicateExportFix',
    50,
    'Remove duplicate export',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  AstNode? findTargetNode(AstNode node) {
    return node is ExportDirective
        ? node
        : node.thisOrAncestorOfType<ExportDirective>();
  }
}
