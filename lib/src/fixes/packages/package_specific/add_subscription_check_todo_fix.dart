// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../../native/saropa_fix.dart';

/// Quick fix for `require_subscription_status_check`: inserts a TODO reminder.
///
/// When a `build()` method references premium/subscription keywords without
/// a status verification pattern (FutureBuilder, StreamBuilder, checkStatus,
/// etc.), this fix inserts a `// TODO: verify subscription status` comment
/// at the top of the method body to prompt the developer to add proper
/// entitlement checking before showing gated content.
///
/// The fix targets the enclosing [MethodDeclaration] and inserts immediately
/// after the opening brace of the block body.
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
    final indent = getLineIndent(block);

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(
        block.leftBracket.end,
        '\n$indent  // TODO: verify subscription status before showing premium content',
      );
    });
  }
}
