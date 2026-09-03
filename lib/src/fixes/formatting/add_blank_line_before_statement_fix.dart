// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Add a blank line directly before a flagged statement.
///
/// Unlike [AddBlankLineBeforeFix] (used by the case/constructor/method/else
/// family), this fix does NOT climb to the enclosing [ClassMember] or
/// [SwitchMember] — `break`/`continue`/`throw` statements live inside a
/// method *body*, so climbing to the enclosing declaration would insert the
/// blank line before the whole method instead of before the statement
/// itself. Insertion happens at the statement's own offset instead.
class AddBlankLineBeforeStatementFix extends SaropaFixProducer {
  AddBlankLineBeforeStatementFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addBlankLineBeforeStatement',
    50,
    'Add blank line',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // The diagnostic is reported on the statement node itself (BreakStatement,
    // ContinueStatement, or the ExpressionStatement wrapping a throw), so the
    // covering node found by the change-builder is usually that statement
    // directly. Fall back to walking up to the nearest Statement ancestor in
    // case the resolver hands back a more specific inner node.
    final Statement? target = node is Statement
        ? node
        : node.thisOrAncestorOfType<Statement>();
    if (target == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(target.offset, '\n');
    });
  }
}
