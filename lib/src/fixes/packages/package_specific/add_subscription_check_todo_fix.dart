// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../../native/saropa_fix.dart';

/// Quick fix: Add a TODO comment to verify subscription status.
///
/// Inserts a reminder comment at the top of the build method body.
class AddSubscriptionCheckTodoFix extends SaropaFixProducer {
  AddSubscriptionCheckTodoFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addSubscriptionCheckTodo',
    50,
    'Add TODO: verify subscription status',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final method = node is MethodDeclaration
        ? node
        : node.thisOrAncestorOfType<MethodDeclaration>();
    if (method == null) return;

    final body = method.body;
    if (body is! BlockFunctionBody) return;

    final block = body.block;
    final indent = _getIndent(block);

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(
        block.leftBracket.end,
        '\n$indent  // TODO: verify subscription status before showing premium content',
      );
    });
  }

  String _getIndent(AstNode node) {
    final lineInfo = unitResult.lineInfo;
    final line = lineInfo.getLocation(node.offset).lineNumber - 1;
    final lineStart = lineInfo.getOffsetOfLine(line);
    return unitResult.content.substring(lineStart, node.offset);
  }
}
