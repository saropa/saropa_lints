// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Wrap print() call in `if (kDebugMode)` guard.
class WrapInDebugModeFix extends SaropaFixProducer {
  WrapInDebugModeFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.wrapInDebugMode',
    50,
    'Wrap in kDebugMode check',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // Find the enclosing ExpressionStatement (print(...);)
    final invocation = node is MethodInvocation
        ? node
        : node.thisOrAncestorOfType<MethodInvocation>();
    if (invocation == null) return;

    final statement = invocation.thisOrAncestorOfType<ExpressionStatement>();
    if (statement == null) return;

    final source = statement.toSource();
    final indent = getLineIndent(statement);

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(statement.offset, statement.length),
        'if (kDebugMode) {\n$indent  $source\n$indent}',
      );
    });
  }
}
