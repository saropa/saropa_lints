// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../../native/saropa_fix.dart';

/// Quick fix: Comment out notifier assignment
class CommentOutNotifierAssignmentFix extends SaropaFixProducer {
  CommentOutNotifierAssignmentFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.commentOutNotifierAssignmentFix',
    50,
    'Comment out notifier assignment',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is AssignmentExpression
        ? node
        : node.thisOrAncestorOfType<AssignmentExpression>();
    if (target == null) return;

    // Find enclosing statement
    final stmt = target.thisOrAncestorOfType<ExpressionStatement>();
    if (stmt == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(stmt.offset, stmt.length),
        '// ${stmt.toSource()}',
      );
    });
  }
}
