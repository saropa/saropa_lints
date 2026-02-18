// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace with ConstrainedBox
class PreferConstrainedBoxOverContainerFix extends SaropaFixProducer {
  PreferConstrainedBoxOverContainerFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferConstrainedBoxOverContainerFix',
    50,
    'Replace with ConstrainedBox',
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
    final replacement = source.replaceFirst('Container(', 'ConstrainedBox(');
    if (replacement == source) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(target.offset, target.length),
        replacement,
      );
    });
  }
}
