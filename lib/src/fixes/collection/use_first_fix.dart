// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Use .first
class UseFirstFix extends SaropaFixProducer {
  UseFirstFix({required super.context});

  static const _fixKind = FixKind('saropa.fix.useFirstFix', 50, 'Use .first');

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

    // Replace list[0] with list.first
    final receiver = target.target;
    if (receiver == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(target.offset, target.length),
        '${receiver.toSource()}.first',
      );
    });
  }
}
