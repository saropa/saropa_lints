// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace `.compareTo(x) == 0` with `== x`.
class UseDirectEqualityFix extends SaropaFixProducer {
  UseDirectEqualityFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.useDirectEquality',
    50,
    'Replace with direct equality',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final binary = node is BinaryExpression
        ? node
        : node.thisOrAncestorOfType<BinaryExpression>();
    if (binary == null) return;

    final left = binary.leftOperand;
    if (left is! MethodInvocation) return;
    if (left.methodName.name != 'compareTo') return;

    final target = left.target;
    if (target == null) return;

    final arg = left.argumentList.arguments.firstOrNull;
    if (arg == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(binary.offset, binary.length),
        '${target.toSource()} == ${arg.toSource()}',
      );
    });
  }
}
