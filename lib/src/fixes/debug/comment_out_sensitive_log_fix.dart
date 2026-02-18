// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Comment out sensitive log statement
class CommentOutSensitiveLogFix extends SaropaFixProducer {
  CommentOutSensitiveLogFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.commentOutSensitiveLogFix',
    50,
    'Comment out sensitive log statement',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is MethodInvocation
        ? node
        : node.thisOrAncestorOfType<MethodInvocation>();
    if (target == null) return;

    // Comment out the entire statement containing the log call
    final statement = target.thisOrAncestorOfType<ExpressionStatement>();
    if (statement == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(statement.offset, statement.length),
        '// ${statement.toSource()}',
      );
    });
  }
}
