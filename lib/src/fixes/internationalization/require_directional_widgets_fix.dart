// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Convert to EdgeInsetsDirectional with start/end
class RequireDirectionalWidgetsFix extends SaropaFixProducer {
  RequireDirectionalWidgetsFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.requireDirectionalWidgetsFix',
    4000,
    'Convert to EdgeInsetsDirectional with start/end',
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
    var replacement = source;
    replacement = replacement.replaceAll(
      'EdgeInsets.',
      'EdgeInsetsDirectional.',
    );
    replacement = replacement.replaceAll('left:', 'start:');
    replacement = replacement.replaceAll('right:', 'end:');

    if (replacement == source) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(target.offset, target.length),
        replacement,
      );
    });
  }
}
