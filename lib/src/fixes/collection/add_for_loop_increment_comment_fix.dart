// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: insert an explanatory comment above the for loop so the
/// prefer_correct_for_loop_increment rule no longer reports (comment exemption).
class AddForLoopIncrementCommentFix extends SaropaFixProducer {
  AddForLoopIncrementCommentFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addForLoopIncrementComment',
    50,
    'Add comment explaining non-standard increment',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final forStatement = node.thisOrAncestorOfType<ForStatement>();
    if (forStatement == null) return;

    final indent = getLineIndent(forStatement);
    const comment =
        '// Non-standard increment: explain why (e.g. step for spacing).';

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleInsertion(forStatement.offset, '$indent$comment\n');
    });
  }
}
