// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Add await before returned expression (return expr → return await expr).
///
/// Matches [PreferReturnAwaitRule].
class AddReturnAwaitFix extends SaropaFixProducer {
  AddReturnAwaitFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addReturnAwait',
    50,
    'Add await before returned expression',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final ReturnStatement? returnStmt = node is ReturnStatement
        ? node
        : node.thisOrAncestorOfType<ReturnStatement>();
    if (returnStmt == null) return;

    final Expression? expression = returnStmt.expression;
    if (expression == null) return;

    // Insert "await " right after "return " (before the expression)
    final int insertOffset = expression.offset;
    await builder.addDartFileEdit(file, (b) {
      b.addSimpleInsertion(insertOffset, 'await ');
    });
  }
}
