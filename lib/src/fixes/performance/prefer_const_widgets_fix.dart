// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Add const to widget constructor.
class PreferConstWidgetsFix extends SaropaFixProducer {
  PreferConstWidgetsFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferConstWidgetsFix',
    50,
    'Add const to widget constructor',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is InstanceCreationExpression
        ? node
        : node.thisOrAncestorOfType<InstanceCreationExpression>();
    if (target == null || target.isConst) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(target.offset, 'const ');
    });
  }
}
