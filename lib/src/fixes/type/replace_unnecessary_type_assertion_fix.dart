// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/replace_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Replace unnecessary is check with true (expr is T → true when always true).
///
/// Matches [AvoidUnnecessaryTypeAssertionsRule].
class ReplaceUnnecessaryTypeAssertionFix extends ReplaceNodeFix {
  ReplaceUnnecessaryTypeAssertionFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceUnnecessaryTypeAssertion',
    50,
    'Replace unnecessary type assertion with true',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  String computeReplacement(AstNode node) {
    if (node is! IsExpression) return node.toSource();
    return node.notOperator != null ? 'false' : 'true';
  }
}
