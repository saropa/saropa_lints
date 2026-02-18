// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Comment out print statement in production code.
class CommentOutPrintFix extends SaropaFixProducer {
  CommentOutPrintFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.commentOutPrint',
    50,
    'Comment out print statement',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final stmt = node is ExpressionStatement
        ? node
        : node.thisOrAncestorOfType<ExpressionStatement>();
    if (stmt == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(stmt.offset, stmt.length),
        '// ${stmt.toSource()}',
      );
    });
  }
}
