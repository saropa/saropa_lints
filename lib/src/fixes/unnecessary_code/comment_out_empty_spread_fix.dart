// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Comment out empty spread
class CommentOutEmptySpreadFix extends SaropaFixProducer {
  CommentOutEmptySpreadFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.commentOutEmptySpreadFix',
    50,
    'Comment out empty spread',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is SpreadElement
        ? node
        : node.thisOrAncestorOfType<SpreadElement>();
    if (target == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(target.offset, target.length),
        '/* ${target.toSource()} */',
      );
    });
  }
}
