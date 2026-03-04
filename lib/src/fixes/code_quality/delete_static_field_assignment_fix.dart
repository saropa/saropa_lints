// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/delete_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Remove the statement that assigns to a static field.
///
/// **Rule:** [AvoidAssigningToStaticFieldRule]
///
/// **Behavior:** Deletes the entire [ExpressionStatement] that contains the
/// assignment (e.g. `counter++;` or `_count = 0;`), so instance methods no
/// longer modify static state at that call site. The developer can then
/// refactor to a static method or instance field as appropriate.
class DeleteStaticFieldAssignmentFix extends DeleteNodeFix {
  DeleteStaticFieldAssignmentFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.deleteStaticFieldAssignment',
    50,
    'Remove static field assignment',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  AstNode? findTargetNode(AstNode node) {
    return node.thisOrAncestorOfType<ExpressionStatement>();
  }
}
