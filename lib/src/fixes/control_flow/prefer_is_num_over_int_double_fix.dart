// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace `value is int || value is double` with `value is num`.
///
/// Matches [AvoidDoubleAndIntChecksRule]. The diagnostic is reported at the
/// `BinaryExpression` composed of two `IsExpression` operands sharing the
/// same target. The fix rewrites the entire binary to `<target> is num`.
///
/// Only the `||` variant is fixed — the `&&` variant is always-false dead
/// code (int and double are disjoint), and rewriting it to `is num` would
/// flip semantics from never-true to sometimes-true. The user must delete
/// that branch manually; the rule's message already steers them there.
class PreferIsNumOverIntDoubleFix extends SaropaFixProducer {
  PreferIsNumOverIntDoubleFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferIsNumOverIntDouble',
    50,
    'Replace with value is num',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final AstNode? node = coveringNode;
    if (node == null) return;

    final BinaryExpression? binary = node is BinaryExpression
        ? node
        : node.thisOrAncestorOfType<BinaryExpression>();
    if (binary == null) return;

    // Only the `||` form is a semantics-preserving rewrite; see class doc.
    if (binary.operator.type != TokenType.BAR_BAR) return;

    final Expression left = binary.leftOperand;
    final Expression right = binary.rightOperand;
    if (left is! IsExpression || right is! IsExpression) return;

    final String target = left.expression.toSource();
    if (target != right.expression.toSource()) return;

    final String replacement = '$target is num';

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(binary.offset, binary.length),
        replacement,
      );
    });
  }
}
