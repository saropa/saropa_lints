// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Prefix `const` to a `BorderRadius.circular(...)` call so it
/// becomes a compile-time constant and is not rebuilt every frame.
///
/// Matches `PreferConstBorderRadiusRule`. The rule reports at the
/// [MethodInvocation] (`BorderRadius.circular(x)`); the fix inserts `const `
/// at that node's offset. The rule already verifies the call isn't already
/// inside a const context, so a prefix here is always meaningful.
class PreferConstBorderRadiusFix extends SaropaFixProducer {
  PreferConstBorderRadiusFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferConstBorderRadius',
    50,
    'Add const keyword',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final AstNode? node = coveringNode;
    if (node == null) return;

    final MethodInvocation? call = node is MethodInvocation
        ? node
        : node.thisOrAncestorOfType<MethodInvocation>();
    if (call == null) return;

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleInsertion(call.offset, 'const ');
    });
  }
}
