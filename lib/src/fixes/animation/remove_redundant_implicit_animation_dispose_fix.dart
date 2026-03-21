// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../implicit_animation_dispose_cast_ast.dart';
import '../../native/saropa_fix.dart';
import '../common/replace_node_fix.dart';

/// Removes `(animation as CurvedAnimation).dispose();` in implicit animation state.
///
/// Matches [AvoidImplicitAnimationDisposeCastRule].
class RemoveRedundantImplicitAnimationDisposeFix extends ReplaceNodeFix {
  RemoveRedundantImplicitAnimationDisposeFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeRedundantImplicitAnimationDispose',
    50,
    'Remove redundant dispose on implicit animation',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  AstNode? findTargetNode(AstNode node) {
    if (node is! AsExpression) return node;
    final MethodInvocation? inv = disposeInvocationForCastAsDisposeTarget(node);
    if (inv == null) return node;
    final AstNode? parent = inv.parent;
    if (parent is ExpressionStatement && parent.expression == inv) {
      return parent;
    }
    return node;
  }

  @override
  String computeReplacement(AstNode node) => '';
}
