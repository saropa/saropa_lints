// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Convert single "return expr;" body to expression body "=> expr".
///
/// Matches [PreferReturningShorthandsRule].
class ConvertToExpressionBodyFix extends SaropaFixProducer {
  ConvertToExpressionBodyFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.convertToExpressionBody',
    50,
    'Convert to expression body',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final body = node.thisOrAncestorOfType<BlockFunctionBody>();
    if (body == null) return;

    final block = body.block;
    if (block.statements.length != 1) return;

    final stmt = block.statements.first;
    if (stmt is! ReturnStatement) return;
    final expr = stmt.expression;
    if (expr == null) return;

    final replacement = '=> ${expr.toSource()}';
    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(body.offset, body.length),
        replacement,
      );
    });
  }
}
