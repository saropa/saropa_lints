// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace x != null ? [...x] : [] with [...?x].
///
/// Matches [PreferNullAwareSpreadRule] for the ternary pattern.
class ReplaceConditionalSpreadWithNullAwareFix extends SaropaFixProducer {
  ReplaceConditionalSpreadWithNullAwareFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceConditionalSpreadWithNullAware',
    50,
    'Use [...?x] instead of ternary',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final ConditionalExpression? conditional = node is ConditionalExpression
        ? node
        : node.thisOrAncestorOfType<ConditionalExpression>();
    if (conditional == null) return;

    final Expression condition = conditional.condition;
    final Expression thenExpr = conditional.thenExpression;
    final Expression elseExpr = conditional.elseExpression;

    if (condition is! BinaryExpression ||
        condition.operator.lexeme != '!=' ||
        condition.rightOperand is! NullLiteral) {
      return;
    }
    if (thenExpr is! ListLiteral ||
        thenExpr.elements.length != 1 ||
        elseExpr is! ListLiteral ||
        elseExpr.elements.isNotEmpty) {
      return;
    }

    final CollectionElement first = thenExpr.elements.first;
    if (first is! SpreadElement || first.isNullAware) {
      return;
    }

    final String variableSrc = condition.leftOperand.toSource();
    final String replacement = '[...?$variableSrc]';

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(conditional.offset, conditional.length),
        replacement,
      );
    });
  }
}
