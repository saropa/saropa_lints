// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix base: replace the covering node's text.
///
/// Subclasses provide [computeReplacement] and optionally override
/// [findTargetNode] to target a specific ancestor.
abstract class ReplaceNodeFix extends SaropaFixProducer {
  ReplaceNodeFix({required super.context});

  /// Compute the replacement text for [node].
  String computeReplacement(AstNode node);

  /// Optionally navigate to a different ancestor to replace.
  ///
  /// Override when the [coveringNode] is too narrow (e.g., an identifier
  /// inside a larger expression that should be replaced entirely).
  AstNode? findTargetNode(AstNode node) => node;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = findTargetNode(node);
    if (target == null) return;

    final replacement = computeReplacement(target);
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(target.offset, target.length),
        replacement,
      );
    });
  }
}
