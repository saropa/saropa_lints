// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace `map.keys.contains(key)` with `map.containsKey(key)`.
class UseContainsKeyFix extends SaropaFixProducer {
  UseContainsKeyFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.useContainsKey',
    50,
    'Replace with containsKey()',
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

    // Pattern: map.keys.contains(key)
    final target = invocation.target;
    if (target is! PrefixedIdentifier) return;

    final mapExpr = target.prefix.toSource();
    final arg = invocation.argumentList.arguments.firstOrNull;
    if (arg == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(invocation.offset, invocation.length),
        '$mapExpr.containsKey(${arg.toSource()})',
      );
    });
  }
}
