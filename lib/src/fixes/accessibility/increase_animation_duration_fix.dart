// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Increase duration to 333ms
class IncreaseAnimationDurationFix extends SaropaFixProducer {
  IncreaseAnimationDurationFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.increaseAnimationDurationFix',
    4000,
    'Increase duration to 333ms',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // Find the Duration constructor
    final target = node is InstanceCreationExpression
        ? node
        : node.thisOrAncestorOfType<InstanceCreationExpression>();
    if (target == null) return;

    final source = target.toSource();
    // Replace the milliseconds value with 333
    final msPattern = RegExp(r'milliseconds:\s*\d+');
    final replacement = source.replaceFirst(msPattern, 'milliseconds: 333');
    if (replacement == source) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(target.offset, target.length),
        replacement,
      );
    });
  }
}
