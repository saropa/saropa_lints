// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/replace_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Replace try-catch that only rethrows with just the try body.
///
/// Matches [AvoidOnlyRethrowRule].
///
/// **For developers:** [ReplaceNodeFix]; [findTargetNode] returns [TryStatement]; replacement is try body only.
class RemoveTryCatchOnlyRethrowFix extends ReplaceNodeFix {
  RemoveTryCatchOnlyRethrowFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeTryCatchOnlyRethrowFix',
    50,
    'Remove try-catch that only rethrows',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  AstNode? findTargetNode(AstNode node) {
    final tryStatement = node.thisOrAncestorOfType<TryStatement>();
    return tryStatement;
  }

  @override
  String computeReplacement(AstNode node) {
    if (node is TryStatement) {
      return node.body.toSource();
    }
    return node.toSource();
  }
}
