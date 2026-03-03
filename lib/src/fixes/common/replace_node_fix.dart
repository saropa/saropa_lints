// ignore_for_file: depend_on_referenced_packages

import 'dart:developer' as developer;

/// Reusable quick-fix base: replace the violation node's source with new text.
/// Used by fixes that rewrite an expression or statement (e.g. replace deprecated
/// API with recommended one). Subclass and implement [computeReplacement].
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

    if (file.isEmpty) return;

    final offset = target.offset;
    final length = target.length;
    if (offset < 0 || length < 0) return;

    try {
      await builder.addDartFileEdit(file, (b) {
        b.addSimpleReplacement(SourceRange(offset, length), replacement);
      });
    } catch (e, st) {
      developer.log(
        'ReplaceNodeFix addDartFileEdit failed',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
      // Builder or edit may fail; avoid propagating
    }
  }
}
