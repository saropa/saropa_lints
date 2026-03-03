// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/delete_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Remove assert statement with constant condition.
///
/// Matches [AvoidConstantAssertConditionsRule]. Removes dead code.
///
/// **For developers:** Targets [AssertStatement] via [findTargetNode]; uses [DeleteNodeFix].
class RemoveConstantAssertFix extends DeleteNodeFix {
  RemoveConstantAssertFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeConstantAssertFix',
    50,
    'Remove constant assert',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  AstNode? findTargetNode(AstNode node) {
    return node is AssertStatement
        ? node
        : node.thisOrAncestorOfType<AssertStatement>();
  }
}
