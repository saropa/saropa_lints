// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Wrap an unhandled Future-returning call with `unawaited()`.
///
/// Matches [AvoidAsyncCallInSyncFunctionRule].
class WrapUnawaitedFix extends SaropaFixProducer {
  WrapUnawaitedFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.wrapUnawaited',
    50,
    'Wrap with unawaited()',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // The rule reports on the MethodInvocation node.
    final invocation = node is MethodInvocation
        ? node
        : node.thisOrAncestorOfType<MethodInvocation>();
    if (invocation == null) return;

    // Wrap the call: `foo()` → `unawaited(foo())`
    await builder.addDartFileEdit(file, (b) {
      b.addSimpleInsertion(invocation.offset, 'unawaited(');
      b.addSimpleInsertion(invocation.end, ')');
    });
  }
}
