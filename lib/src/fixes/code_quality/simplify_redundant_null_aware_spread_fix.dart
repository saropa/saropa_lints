// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Simplify ...?(x ?? []) to ...?x.
///
/// Matches [PreferNullAwareSpreadRule] when the spread is already null-aware
/// but the expression is a redundant (x ?? []) pattern.
class SimplifyRedundantNullAwareSpreadFix extends SaropaFixProducer {
  SimplifyRedundantNullAwareSpreadFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.simplifyRedundantNullAwareSpread',
    50,
    'Simplify to ...?x',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final SpreadElement? spread = node is SpreadElement
        ? node
        : node.thisOrAncestorOfType<SpreadElement>();
    if (spread == null || !spread.isNullAware) return;

    final Expression expr = spread.expression;
    if (expr is! BinaryExpression || expr.operator.lexeme != '??') return;

    final Expression right = expr.rightOperand;
    if (right is! ListLiteral || right.elements.isNotEmpty) return;

    final String replacement = expr.leftOperand.toSource();

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(expr.offset, expr.length),
        replacement,
      );
    });
  }
}
