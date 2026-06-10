// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: replace an explicit null-check-then-call with the null-aware
/// operator (`?.`).
///
/// Matches `PreferNullAwareMethodCallsRule`, which reports two shapes:
/// - `if (x != null) { x.foo(args); }` → `x?.foo(args);`
/// - `x != null ? x.foo() : null` → `x?.foo()`
///
/// The rewrite inserts a `?` immediately before the receiver's `.` token,
/// reusing the exact original source for the receiver, member, and arguments,
/// so formatting and argument expressions are preserved verbatim.
class PreferNullAwareCallFix extends SaropaFixProducer {
  PreferNullAwareCallFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferNullAwareCall',
    50,
    'Use null-aware operator (?.)',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final content = unitResult.content;
    if (content.isEmpty) return;

    // Ternary shape is checked first: a null-guard ternary can itself sit
    // inside an `if`, so resolving the if-statement first would target the
    // wrong node.
    final ConditionalExpression? ternary = node is ConditionalExpression
        ? node
        : node.thisOrAncestorOfType<ConditionalExpression>();
    if (ternary != null && _isNullGuardTernary(ternary)) {
      final String? rewrite = _nullAwareSource(ternary.thenExpression, content);
      if (rewrite == null) return;
      await builder.addDartFileEdit(file, (b) {
        b.addSimpleReplacement(
          SourceRange(ternary.offset, ternary.length),
          rewrite,
        );
      });
      return;
    }

    final IfStatement? ifStmt = node is IfStatement
        ? node
        : node.thisOrAncestorOfType<IfStatement>();
    if (ifStmt == null || ifStmt.elseStatement != null) return;

    Statement then = ifStmt.thenStatement;
    if (then is Block && then.statements.length == 1) {
      then = then.statements.single;
    }
    if (then is! ExpressionStatement) return;

    final String? rewrite = _nullAwareSource(then.expression, content);
    if (rewrite == null) return;

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(ifStmt.offset, ifStmt.length),
        '$rewrite;',
      );
    });
  }

  /// Validates that [node] is a `<expr> != null ? <call> : null` ternary so the
  /// fix does not grab an unrelated enclosing conditional expression.
  bool _isNullGuardTernary(ConditionalExpression node) {
    final cond = node.condition;
    if (cond is! BinaryExpression || cond.operator.type != TokenType.BANG_EQ) {
      return false;
    }
    final bool hasNull =
        cond.leftOperand is NullLiteral || cond.rightOperand is NullLiteral;
    if (!hasNull) return false;
    if (node.elseExpression is! NullLiteral) return false;
    final then = node.thenExpression;
    return then is MethodInvocation || then is PropertyAccess;
  }

  /// Returns [expr]'s source with a `?` inserted before its member `.` token,
  /// or `null` if [expr] is not a plain `.`-accessed call/property.
  String? _nullAwareSource(Expression expr, String content) {
    Token? operator;
    if (expr is MethodInvocation) {
      operator = expr.operator;
    } else if (expr is PropertyAccess) {
      operator = expr.operator;
    }
    if (operator == null || operator.type != TokenType.PERIOD) return null;
    if (expr.offset < 0 || expr.end > content.length) return null;
    if (operator.offset < expr.offset || operator.offset >= expr.end) {
      return null;
    }
    return '${content.substring(expr.offset, operator.offset)}?'
        '${content.substring(operator.offset, expr.end)}';
  }
}
