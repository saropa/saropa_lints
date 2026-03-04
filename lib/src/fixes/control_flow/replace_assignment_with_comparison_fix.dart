// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace assignment (=) with comparison (==) in conditions.
///
/// Matches [AvoidAssignmentsAsConditionsRule].
class ReplaceAssignmentWithComparisonFix extends SaropaFixProducer {
  ReplaceAssignmentWithComparisonFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceAssignmentWithComparison',
    50,
    'Replace = with ==',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final assignment = node is AssignmentExpression
        ? node
        : node.thisOrAncestorOfType<AssignmentExpression>();
    if (assignment == null) return;

    // Only offer for simple assignment (=), not compound (+=, etc.)
    final token = assignment.operator;
    if (token.type != TokenType.EQ) return;

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(SourceRange(token.offset, token.length), '==');
    });
  }
}
