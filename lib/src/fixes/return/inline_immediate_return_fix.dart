// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Return expression directly
class InlineImmediateReturnFix extends SaropaFixProducer {
  InlineImmediateReturnFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.inlineImmediateReturnFix',
    50,
    'Return expression directly',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // Find the variable declaration statement
    final varStmt = node is VariableDeclarationStatement
        ? node
        : node.thisOrAncestorOfType<VariableDeclarationStatement>();
    if (varStmt == null) return;

    final parent = varStmt.parent;
    if (parent is! Block) return;

    final stmts = parent.statements;
    final idx = stmts.indexOf(varStmt);
    if (idx < 0 || idx + 1 >= stmts.length) return;

    final nextStmt = stmts[idx + 1];
    if (nextStmt is! ReturnStatement) return;

    final decls = varStmt.variables.variables;
    if (decls.length != 1) return;
    final decl = decls.first;
    final init = decl.initializer;
    if (init == null) return;

    final returnExpr = nextStmt.expression;
    if (returnExpr is! SimpleIdentifier) return;
    if (returnExpr.name != decl.name.lexeme) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(varStmt.offset, nextStmt.end - varStmt.offset),
        'return ${init.toSource()};',
      );
    });
  }
}
