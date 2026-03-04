// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Remove redundant nested if with same condition.
///
/// Matches [NoEqualNestedConditionsRule]. Replaces the inner if with
/// just its then-branch so the condition is not duplicated.
class FlattenRedundantNestedConditionFix extends SaropaFixProducer {
  FlattenRedundantNestedConditionFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.flattenRedundantNestedCondition',
    50,
    'Remove redundant nested condition',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final IfStatement? innerIf = node.thisOrAncestorOfType<IfStatement>();
    if (innerIf == null) return;

    final Statement thenBranch = innerIf.thenStatement;
    final String replacement = thenBranch.toSource();

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(innerIf.offset, innerIf.length),
        replacement,
      );
    });
  }
}
