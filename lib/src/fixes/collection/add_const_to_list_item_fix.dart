// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Add const before a list item constructor call.
///
/// Matches [RequireConstListItemsRule].
class AddConstToListItemFix extends SaropaFixProducer {
  AddConstToListItemFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addConstToListItem',
    50,
    'Add const to list item',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final expr = node is InstanceCreationExpression
        ? node
        : node.thisOrAncestorOfType<InstanceCreationExpression>();
    if (expr == null) return;

    if (expr.keyword?.lexeme == 'const') return;

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleInsertion(expr.offset, 'const ');
    });
  }
}
