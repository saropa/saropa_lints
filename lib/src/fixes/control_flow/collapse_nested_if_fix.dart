// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: merge a nested `if` (with no `else` on either level) into its
/// parent by combining the two conditions with `&&`.
///
/// Matches `AvoidCollapsibleIfRule`, which reports at the outer [IfStatement]
/// when its then-body is a single inner `if` and neither `if` has an `else`.
/// `if (a) { if (b) { body } }` becomes `if ((a) && (b)) { body }`.
///
/// Each condition is wrapped in parentheses so a low-precedence operator in
/// either one (e.g. `a || c`) cannot bind incorrectly against the inserted
/// `&&`. `dart format` collapses the redundant parens on simple conditions.
class CollapseNestedIfFix extends SaropaFixProducer {
  CollapseNestedIfFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.collapseNestedIf',
    50,
    'Merge nested if into a single condition',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final outer = node is IfStatement
        ? node
        : node.thisOrAncestorOfType<IfStatement>();
    if (outer == null || outer.elseStatement != null) return;

    final IfStatement? inner = _singleInnerIf(outer.thenStatement);
    if (inner == null || inner.elseStatement != null) return;

    final content = unitResult.content;
    if (content.isEmpty) return;

    final Expression outerCond = outer.expression;
    final Expression innerCond = inner.expression;
    final Statement innerBody = inner.thenStatement;
    if (outerCond.offset < 0 ||
        innerBody.end > content.length ||
        innerBody.offset < 0) {
      return;
    }

    final String outerSource = content.substring(
      outerCond.offset,
      outerCond.end,
    );
    final String innerSource = content.substring(
      innerCond.offset,
      innerCond.end,
    );
    final String bodySource = content.substring(
      innerBody.offset,
      innerBody.end,
    );

    final String replacement =
        'if (($outerSource) && ($innerSource)) '
        '$bodySource';

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(outer.offset, outer.end - outer.offset),
        replacement,
      );
    });
  }

  /// Returns the inner `if` when [thenStatement] is a single `if` statement,
  /// either directly or as the sole statement of a block.
  IfStatement? _singleInnerIf(Statement thenStatement) {
    if (thenStatement is IfStatement) return thenStatement;
    if (thenStatement is Block && thenStatement.statements.length == 1) {
      final Statement single = thenStatement.statements.first;
      if (single is IfStatement) return single;
    }
    return null;
  }
}
