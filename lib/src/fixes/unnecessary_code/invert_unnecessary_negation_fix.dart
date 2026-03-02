// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Simplify !(a == b) to a != b, !!x to x, etc.
class InvertUnnecessaryNegationFix extends SaropaFixProducer {
  InvertUnnecessaryNegationFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.invertUnnecessaryNegationFix',
    50,
    'Simplify negation',
  );

  @override
  FixKind get fixKind => _fixKind;

  static const _invertedOp = <TokenType, TokenType>{
    TokenType.EQ_EQ: TokenType.BANG_EQ,
    TokenType.BANG_EQ: TokenType.EQ_EQ,
    TokenType.LT: TokenType.GT_EQ,
    TokenType.GT: TokenType.LT_EQ,
    TokenType.LT_EQ: TokenType.GT,
    TokenType.GT_EQ: TokenType.LT,
  };

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final prefix = node is PrefixExpression
        ? node
        : node.thisOrAncestorOfType<PrefixExpression>();
    if (prefix == null || prefix.operator.type != TokenType.BANG) return;

    final operand = prefix.operand;

    // Double negation: !!x -> x
    if (operand is PrefixExpression &&
        operand.operator.type == TokenType.BANG) {
      await builder.addDartFileEdit(file, (builder) {
        builder.addSimpleReplacement(
          SourceRange(prefix.offset, prefix.length),
          operand.operand.toSource(),
        );
      });
      return;
    }

    // !(a op b) -> a inv_op b
    if (operand is ParenthesizedExpression) {
      final inner = operand.expression;
      if (inner is BinaryExpression) {
        final op = inner.operator.type;
        final inv = _invertedOp[op];
        if (inv == null) return;
        final opStr = const <TokenType, String>{
          TokenType.EQ_EQ: '==',
          TokenType.BANG_EQ: '!=',
          TokenType.LT: '<',
          TokenType.GT: '>',
          TokenType.LT_EQ: '<=',
          TokenType.GT_EQ: '>=',
        };
        final left = inner.leftOperand.toSource();
        final right = inner.rightOperand.toSource();
        final replacement = '$left ${opStr[inv]} $right';
        await builder.addDartFileEdit(file, (builder) {
          builder.addSimpleReplacement(
            SourceRange(prefix.offset, prefix.length),
            replacement,
          );
        });
      }
    }
  }
}
