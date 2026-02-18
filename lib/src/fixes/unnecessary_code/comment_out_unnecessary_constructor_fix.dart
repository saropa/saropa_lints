// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Comment out unnecessary constructor
class CommentOutUnnecessaryConstructorFix extends SaropaFixProducer {
  CommentOutUnnecessaryConstructorFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.commentOutUnnecessaryConstructorFix',
    50,
    'Comment out unnecessary constructor',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is ConstructorDeclaration
        ? node
        : node.thisOrAncestorOfType<ConstructorDeclaration>();
    if (target == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(target.offset, target.length),
        '// ${target.toSource()}',
      );
    });
  }
}
