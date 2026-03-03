// ignore_for_file: depend_on_referenced_packages

import 'dart:developer' as developer;

/// Reusable quick-fix base: insert text at the violation location.
/// Used by many rule-specific fixes that only need to add a snippet (e.g. add
/// a mounted check, add a const keyword). Subclass and implement [insertionText].
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

    final text = insertionText;
    if (text.isEmpty) return; // Defensive: no insertion text

    if (file.isEmpty) return;

    final offset = insertBefore ? target.offset : target.end;
    if (offset < 0) return;

    try {
      await builder.addDartFileEdit(file, (b) {
        b.addSimpleInsertion(offset, text);
      });
    } catch (e, st) {
      developer.log(
        'InsertTextFix addDartFileEdit failed',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
      // Builder or edit may fail; avoid propagating
    }
  }
}
