// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: collapse an `if`/`else` (or `if` + following `return`) that
/// returns one boolean in one branch and the opposite in the other into a
/// single `return <condition>;` (or `return !(<condition>);`).
///
/// Matches both `PreferReturningConditionRule` (the `if`/`else` shape) and
/// `AvoidUnnecessaryIfRule` (the `if (c) return true; return false;` shape).
/// Both rules report at the [IfStatement] node, so this producer walks up to
/// the enclosing `if` and reconstructs the equivalent direct return.
///
/// The condition is wrapped in parentheses when negated (`return !(c);`) so the
/// fix stays correct regardless of the operator precedence inside `c` — e.g.
/// `if (a || b) return false; return true;` becomes `return !(a || b);`, never
/// the wrong `return !a || b;`.
class ReturnConditionFix extends SaropaFixProducer {
  ReturnConditionFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.returnCondition',
    50,
    'Return the condition directly',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final ifStmt = node is IfStatement
        ? node
        : node.thisOrAncestorOfType<IfStatement>();
    if (ifStmt == null) return;

    // The boolean returned by the then-branch decides whether the condition is
    // returned as-is or negated.
    final bool? thenBool = _returnedBool(ifStmt.thenStatement);
    if (thenBool == null) return;

    final content = unitResult.content;
    if (content.isEmpty) return;

    final Expression condition = ifStmt.expression;
    if (condition.offset < 0 || condition.end > content.length) return;
    final String conditionSource = content.substring(
      condition.offset,
      condition.end,
    );
    final String replacement = thenBool
        ? 'return $conditionSource;'
        : 'return !($conditionSource);';

    // Determine the span to replace: the whole if/else, or the if plus the
    // following sibling `return <opposite-bool>;`.
    final int endOffset;
    final Statement? elseStatement = ifStmt.elseStatement;
    if (elseStatement != null) {
      // if/else shape — must return the opposite boolean to be a valid target.
      final bool? elseBool = _returnedBool(elseStatement);
      if (elseBool == null || elseBool == thenBool) return;
      endOffset = ifStmt.end;
    } else {
      // if + following return shape — the next sibling statement carries the
      // opposite boolean and is consumed by the replacement.
      final parent = ifStmt.parent;
      if (parent is! Block) return;
      final int idx = parent.statements.indexOf(ifStmt);
      if (idx < 0 || idx >= parent.statements.length - 1) return;
      final Statement next = parent.statements[idx + 1];
      if (next is! ReturnStatement) return;
      final Expression? nextExpr = next.expression;
      if (nextExpr is! BooleanLiteral || nextExpr.value == thenBool) return;
      endOffset = next.end;
    }

    if (endOffset <= ifStmt.offset) return;

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(ifStmt.offset, endOffset - ifStmt.offset),
        replacement,
      );
    });
  }

  /// Returns `true`/`false` if [statement] (or a single-statement block) is a
  /// `return <bool literal>;`, otherwise `null`.
  bool? _returnedBool(Statement statement) {
    ReturnStatement? returnStmt;
    if (statement is ReturnStatement) {
      returnStmt = statement;
    } else if (statement is Block && statement.statements.length == 1) {
      final Statement single = statement.statements.first;
      if (single is ReturnStatement) {
        returnStmt = single;
      }
    }
    final Expression? expr = returnStmt?.expression;
    return expr is BooleanLiteral ? expr.value : null;
  }
}
