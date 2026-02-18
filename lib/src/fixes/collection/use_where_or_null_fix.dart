// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace `firstWhere(..., orElse: () => null)` with
/// `firstWhereOrNull(...)`.
class UseWhereOrNullFix extends SaropaFixProducer {
  UseWhereOrNullFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.useWhereOrNull',
    50,
    'Replace with *OrNull variant',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final invocation = node is MethodInvocation
        ? node
        : node.thisOrAncestorOfType<MethodInvocation>();
    if (invocation == null) return;

    final methodName = invocation.methodName.name;
    final target = invocation.target;
    if (target == null) return;

    // Map method names to OrNull variants
    final String replacement;
    switch (methodName) {
      case 'firstWhere':
        replacement = 'firstWhereOrNull';
      case 'lastWhere':
        replacement = 'lastWhereOrNull';
      case 'singleWhere':
        replacement = 'singleWhereOrNull';
      default:
        return;
    }

    // Get the predicate (first positional arg), skip orElse
    final args = invocation.argumentList.arguments;
    final predicate = args.firstOrNull;
    if (predicate == null || predicate is NamedExpression) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(invocation.offset, invocation.length),
        '${target.toSource()}.$replacement(${predicate.toSource()})',
      );
    });
  }
}
