// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Use AlertDialog.adaptive()
class UseAdaptiveDialogFix extends SaropaFixProducer {
  UseAdaptiveDialogFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.useAdaptiveDialogFix',
    4000,
    'Use AlertDialog.adaptive()',
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
    if (target == null) return;

    final source = target.toSource();
    final replacement = source.replaceFirst(
      'AlertDialog(',
      'AlertDialog.adaptive(',
    );

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(target.offset, target.length),
        replacement,
      );
    });
  }
}
