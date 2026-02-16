// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../native/saropa_fix.dart';

/// Quick fix: comment out a `debugPrint(...)` statement.
///
/// Replaces the containing [ExpressionStatement] with a commented-out version.
class CommentOutDebugPrintFix extends SaropaFixProducer {
  CommentOutDebugPrintFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.commentOutDebugPrint',
    50,
    'Comment out debugPrint call',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // Find the containing ExpressionStatement to comment the whole line.
    final statement = node is ExpressionStatement
        ? node
        : node.thisOrAncestorOfType<ExpressionStatement>();
    if (statement == null) return;

    final source = statement.toSource();

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(statement.offset, statement.length),
        '// $source',
      );
    });
  }
}
