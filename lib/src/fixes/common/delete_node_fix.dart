// ignore_for_file: depend_on_referenced_packages

import 'dart:developer' as developer;

/// Reusable quick-fix base: delete the violation node (or an ancestor via [findTargetNode]).
/// Used by fixes that remove dead code, redundant statements, or deprecated usages.
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

    if (file.isEmpty) return;

    final offset = target.offset;
    final length = target.length;
    if (offset < 0 || length < 0) return;

    try {
      await builder.addDartFileEdit(file, (b) {
        b.addDeletion(SourceRange(offset, length));
      });
    } catch (e, st) {
      developer.log(
        'DeleteNodeFix addDartFileEdit failed',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
      // Builder or edit may fail; avoid propagating
    }
  }
}
