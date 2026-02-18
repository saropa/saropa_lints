// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace with maybePop
class ReplaceWithMaybePopFix extends SaropaFixProducer {
  ReplaceWithMaybePopFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceWithMaybePopFix',
    50,
    'Replace with maybePop',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is MethodInvocation
        ? node
        : node.thisOrAncestorOfType<MethodInvocation>();
    if (target == null) return;

    // Replace Navigator.of(context).pop() with Navigator.of(context).maybePop()
    final methodName = target.methodName;
    if (methodName.name != 'pop') return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(methodName.offset, methodName.length),
        'maybePop',
      );
    });
  }
}
