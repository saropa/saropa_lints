// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/replace_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Remove unnecessary cast (expr as T → expr).
///
/// Matches [AvoidUnnecessaryTypeCastsRule].
class RemoveUnnecessaryTypeCastFix extends ReplaceNodeFix {
  RemoveUnnecessaryTypeCastFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeUnnecessaryTypeCast',
    50,
    'Remove unnecessary type cast',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  String computeReplacement(AstNode node) {
    if (node is! AsExpression) return node.toSource();
    return node.expression.toSource();
  }
}
