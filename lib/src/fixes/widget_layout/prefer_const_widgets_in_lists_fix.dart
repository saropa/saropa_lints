// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Prefix `const` to a list literal of widgets so the entire
/// list is a compile-time constant and is not rebuilt every frame.
///
/// Matches `PreferConstWidgetsInListsRule`. The rule already verified:
/// - the list isn't already explicitly `const`,
/// - it isn't in an enclosing const context,
/// - every element is either a const-capable widget construction or a
///   spread (so the literal can legally be const).
/// We just insert `const ` at the literal's offset.
class PreferConstWidgetsInListsFix extends SaropaFixProducer {
  PreferConstWidgetsInListsFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferConstWidgetsInLists',
    50,
    'Add const keyword',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final AstNode? node = coveringNode;
    if (node == null) return;

    final ListLiteral? list = node is ListLiteral
        ? node
        : node.thisOrAncestorOfType<ListLiteral>();
    if (list == null) return;
    // Already const — defensive, the rule should have skipped this case.
    if (list.constKeyword != null) return;

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleInsertion(list.offset, 'const ');
    });
  }
}
