// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

/// Shared AST helper for [AvoidImplicitAnimationDisposeCastRule] and its quick fix.
///
/// When [castNode] is the receiver of `.dispose()` (optionally wrapped in
/// [ParenthesizedExpression]), returns that [MethodInvocation]. Uses
/// [MethodInvocation.realTarget] so detection matches the analyzer’s view of the
/// invocation target (consistent with cascade / postfix edge cases).
MethodInvocation? disposeInvocationForCastAsDisposeTarget(
  AsExpression castNode,
) {
  AstNode? outer = castNode.parent;
  if (outer is ParenthesizedExpression) {
    outer = outer.parent;
  }
  if (outer is! MethodInvocation) return null;
  final MethodInvocation inv = outer;
  if (inv.methodName.name != 'dispose') return null;

  final Expression? recv = inv.realTarget;
  if (recv == null) return null;
  if (identical(recv, castNode)) return inv;
  if (recv is ParenthesizedExpression && identical(recv.expression, castNode)) {
    return inv;
  }
  return null;
}
