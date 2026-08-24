import 'package:analyzer/dart/ast/ast.dart';

/// Positional-argument shape for the common `dart:html` same-window scheduling
/// hack: `postMessage` with an empty or null payload and target origin `'*'`.
///
/// Used by [PreferScheduleMicrotaskOverWindowPostmessageRule] after the call is
/// bound to `Window` / `WindowBase.postMessage` from `dart:html`.
///
/// Returns false when a non-empty third positional argument (message ports) is
/// present, to avoid flagging setups that plausibly use real channels.
bool windowPostMessageArgsLookLikeSchedulingHack(MethodInvocation node) {
  if (node.methodName.name != 'postMessage') return false;
  // analyzer 13: .arguments returns NodeList<Argument>; unwrap each via
  // .argumentExpression to get the underlying Expression.
  final args = node.argumentList.arguments;
  if (args.length < 2) return false;

  final Expression first = args[0].argumentExpression;
  final bool emptyOrNull =
      first is NullLiteral ||
      (first is SimpleStringLiteral && first.value.isEmpty);
  if (!emptyOrNull) return false;

  final Expression second = args[1].argumentExpression;
  if (second is! SimpleStringLiteral) return false;
  if (second.value != '*') return false;

  if (args.length >= 3) {
    final Expression third = args[2].argumentExpression;
    if (third is ListLiteral && third.elements.isNotEmpty) {
      return false;
    }
  }
  return true;
}
