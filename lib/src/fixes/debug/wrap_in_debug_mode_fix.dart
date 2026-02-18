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
    final indent = _getIndent(statement);

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(statement.offset, statement.length),
        'if (kDebugMode) {\n$indent  $source\n$indent}',
      );
    });
  }

  String _getIndent(AstNode node) {
    final lineInfo = unitResult.lineInfo;
    final line = lineInfo.getLocation(node.offset).lineNumber - 1;
    final lineStart = lineInfo.getOffsetOfLine(line);
    final content = unitResult.content;
    final indent = StringBuffer();
    for (var i = lineStart; i < content.length; i++) {
      final ch = content[i];
      if (ch == ' ' || ch == '\t') {
        indent.write(ch);
      } else {
        break;
      }
    }
    return indent.toString();
  }
}
