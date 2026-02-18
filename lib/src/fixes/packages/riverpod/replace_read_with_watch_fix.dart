// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../../native/saropa_fix.dart';

/// Quick fix: Replace ref.read with ref.watch
class ReplaceReadWithWatchFix extends SaropaFixProducer {
  ReplaceReadWithWatchFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceReadWithWatchFix',
    50,
    'Replace ref.read with ref.watch',
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

    // Replace ref.read with ref.watch
    final methodName = target.methodName;
    if (methodName.name != 'read') return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(methodName.offset, methodName.length),
        'watch',
      );
    });
  }
}
