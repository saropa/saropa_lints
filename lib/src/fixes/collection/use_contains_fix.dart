// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Use .contains()
class UseContainsFix extends SaropaFixProducer {
  UseContainsFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.useContainsFix',
    50,
    'Use .contains()',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is BinaryExpression
        ? node
        : node.thisOrAncestorOfType<BinaryExpression>();
    if (target == null) return;

    // Pattern: list.indexOf(element) != -1 -> list.contains(element)
    final left = target.leftOperand;
    if (left is! MethodInvocation) return;
    if (left.methodName.name != 'indexOf') return;

    final receiver = left.target;
    if (receiver == null) return;
    final args = left.argumentList.arguments;
    if (args.isEmpty) return;

    final element = args.first.toSource();
    final receiverSrc = receiver.toSource();
    final op = target.operator.lexeme;

    // != -1, >= 0, > -1 mean "contains"; == -1, < 0 mean "not contains"
    final isPositive = op == '!=' || op == '>=' || op == '>';
    final replacement = isPositive
        ? '$receiverSrc.contains($element)'
        : '!$receiverSrc.contains($element)';

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(target.offset, target.length),
        replacement,
      );
    });
  }
}
