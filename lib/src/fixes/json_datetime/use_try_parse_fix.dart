// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace `Type.parse(x)` with `Type.tryParse(x)`.
class UseTryParseFix extends SaropaFixProducer {
  UseTryParseFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.useTryParse',
    50,
    'Replace with tryParse',
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
    if (invocation.methodName.name != 'parse') return;

    // Replace "parse" with "tryParse" in the method name
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(invocation.methodName.offset, invocation.methodName.length),
        'tryParse',
      );
    });
  }
}
