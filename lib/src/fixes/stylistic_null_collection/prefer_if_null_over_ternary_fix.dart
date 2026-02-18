// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace with ?? operator
class PreferIfNullOverTernaryFix extends SaropaFixProducer {
  PreferIfNullOverTernaryFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferIfNullOverTernaryFix',
    4000,
    'Replace with ?? operator',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is ConditionalExpression
        ? node
        : node.thisOrAncestorOfType<ConditionalExpression>();
    if (target == null) return;

    final condition = target.condition;
    if (condition is! BinaryExpression) return;

    final op = condition.operator.lexeme;
    // Verify this is a null comparison
    final isNullRight = condition.rightOperand is NullLiteral;
    if (!isNullRight) return;

    String replacement;
    if (op == '!=') {
      // x != null ? x : y -> x ?? y
      final variable = condition.leftOperand.toSource();
      final defaultValue = target.elseExpression.toSource();
      replacement = '$variable ?? $defaultValue';
    } else if (op == '==') {
      // x == null ? y : x -> x ?? y
      final variable = condition.leftOperand.toSource();
      final defaultValue = target.thenExpression.toSource();
      replacement = '$variable ?? $defaultValue';
    } else {
      return;
    }

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(target.offset, target.length),
        replacement,
      );
    });
  }
}
