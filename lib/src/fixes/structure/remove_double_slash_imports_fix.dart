// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/replace_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Remove double slashes from import/export URI.
class RemoveDoubleSlashImportsFix extends ReplaceNodeFix {
  RemoveDoubleSlashImportsFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeDoubleSlashImportsFix',
    50,
    'Remove double slashes from import path',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  String computeReplacement(AstNode node) {
    final literal = node is SimpleStringLiteral
        ? node
        : node.thisOrAncestorOfType<SimpleStringLiteral>();
    if (literal == null) return node.toSource();
    final value = literal.value;
    if (!value.contains('//')) return value;
    final fixed = value.replaceAll('//', '/');
    return "'$fixed'";
  }
}
