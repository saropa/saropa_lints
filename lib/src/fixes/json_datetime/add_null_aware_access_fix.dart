// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Use null-aware access (?[])
class AddNullAwareAccessFix extends SaropaFixProducer {
  AddNullAwareAccessFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addNullAwareAccessFix',
    50,
    'Use null-aware access (?[])',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is IndexExpression
        ? node
        : node.thisOrAncestorOfType<IndexExpression>();
    if (target == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(target.leftBracket.offset, '?');
    });
  }
}
