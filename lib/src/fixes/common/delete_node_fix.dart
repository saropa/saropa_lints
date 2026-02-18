// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix base: delete the covering node entirely.
///
/// Subclasses optionally override [findTargetNode] to delete a
/// specific ancestor (e.g., the containing [ExpressionStatement]).
abstract class DeleteNodeFix extends SaropaFixProducer {
  DeleteNodeFix({required super.context});

  /// Optionally navigate to a different ancestor to delete.
  ///
  /// Override when the [coveringNode] is too narrow (e.g., delete the
  /// entire statement, not just the identifier).
  AstNode? findTargetNode(AstNode node) => node;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = findTargetNode(node);
    if (target == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addDeletion(SourceRange(target.offset, target.length));
    });
  }
}
