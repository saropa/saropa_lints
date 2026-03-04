// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/delete_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Remove unconditional break or continue statement.
///
/// Matches [AvoidUnconditionalBreakRule]. Removes the statement so the loop
/// can iterate (caller may need to add a proper condition).
///
/// **For developers:** Targets [BreakStatement] or [ContinueStatement] via [DeleteNodeFix].
class RemoveUnconditionalBreakFix extends DeleteNodeFix {
  RemoveUnconditionalBreakFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeUnconditionalBreakFix',
    50,
    'Remove unconditional break/continue',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  AstNode? findTargetNode(AstNode node) {
    return node is BreakStatement || node is ContinueStatement
        ? node
        : node.thisOrAncestorOfType<BreakStatement>() ??
              node.thisOrAncestorOfType<ContinueStatement>();
  }
}
