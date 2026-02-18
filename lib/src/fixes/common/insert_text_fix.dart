// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Quick fix base: insert text before or after the covering node.
///
/// Subclasses provide [insertionText] and optionally override
/// [insertBefore] (defaults to `true`).
abstract class InsertTextFix extends SaropaFixProducer {
  InsertTextFix({required super.context});

  /// Text to insert.
  String get insertionText;

  /// Whether to insert before the node. Override to `false` for suffix.
  bool get insertBefore => true;

  /// Optionally navigate to a different ancestor.
  ///
  /// Override to target a specific parent node instead of [coveringNode].
  AstNode? findTargetNode(AstNode node) => node;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = findTargetNode(node);
    if (target == null) return;

    final offset = insertBefore ? target.offset : target.end;
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(offset, insertionText);
    });
  }
}
