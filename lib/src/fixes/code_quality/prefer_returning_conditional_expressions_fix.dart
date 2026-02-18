// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Convert to conditional expression
class PreferReturningConditionalExpressionsFix extends SaropaFixProducer {
  PreferReturningConditionalExpressionsFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferReturningConditionalExpressionsFix',
    50,
    'Convert to conditional expression',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is IfStatement
        ? node
        : node.thisOrAncestorOfType<IfStatement>();
    if (target == null) return;

    final condition = target.expression.toSource();
    final elseStmt = target.elseStatement;
    if (elseStmt == null) return;

    final thenReturn = _extractReturnExpr(target.thenStatement);
    final elseReturn = _extractReturnExpr(elseStmt);
    if (thenReturn == null || elseReturn == null) return;

    final replacement = 'return ($condition) ? $thenReturn : $elseReturn;';

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(target.offset, target.length),
        replacement,
      );
    });
  }

  static String? _extractReturnExpr(Statement stmt) {
    if (stmt is ReturnStatement) {
      return stmt.expression?.toSource();
    }
    if (stmt is Block && stmt.statements.length == 1) {
      final inner = stmt.statements.first;
      if (inner is ReturnStatement) {
        return inner.expression?.toSource();
      }
    }
    return null;
  }
}
