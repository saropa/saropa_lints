// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Invert operator, e.g. `!(a > b)` → `a <= b`.
class InvertOperatorFix extends SaropaFixProducer {
  InvertOperatorFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.invertOperator',
    50,
    'Invert to direct operator',
  );

  @override
  FixKind get fixKind => _fixKind;

  static const _invertedOps = <TokenType, String>{
    TokenType.EQ_EQ: '!=',
    TokenType.BANG_EQ: '==',
    TokenType.LT: '>=',
    TokenType.GT: '<=',
    TokenType.LT_EQ: '>',
    TokenType.GT_EQ: '<',
  };

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final prefix = node is PrefixExpression
        ? node
        : node.thisOrAncestorOfType<PrefixExpression>();
    if (prefix == null) return;

    final operand = prefix.operand.unParenthesized;
    if (operand is! BinaryExpression) return;

    final inverted = _invertedOps[operand.operator.type];
    if (inverted == null) return;

    final left = operand.leftOperand.toSource();
    final right = operand.rightOperand.toSource();

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(prefix.offset, prefix.length),
        '$left $inverted $right',
      );
    });
  }
}
