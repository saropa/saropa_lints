// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Simplify `x == true` to `x` or `x == false` to `!x`.
class SimplifyBooleanComparisonFix extends SaropaFixProducer {
  SimplifyBooleanComparisonFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.simplifyBooleanComparison',
    50,
    'Simplify boolean comparison',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final binary = node is BinaryExpression
        ? node
        : node.thisOrAncestorOfType<BinaryExpression>();
    if (binary == null) return;

    final left = binary.leftOperand;
    final right = binary.rightOperand;
    final isEquals = binary.operator.type == TokenType.EQ_EQ;

    final BooleanLiteral boolLiteral;
    final Expression otherExpr;

    if (left is BooleanLiteral) {
      boolLiteral = left;
      otherExpr = right;
    } else if (right is BooleanLiteral) {
      boolLiteral = right;
      otherExpr = left;
    } else {
      return;
    }

    // Determine replacement:
    // x == true  → x
    // x == false → !x
    // x != true  → !x
    // x != false → x
    final bool needsNegation = isEquals ? !boolLiteral.value : boolLiteral.value;
    final source = otherExpr.toSource();
    final replacement = needsNegation ? '!$source' : source;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(binary.offset, binary.length),
        replacement,
      );
    });
  }
}
