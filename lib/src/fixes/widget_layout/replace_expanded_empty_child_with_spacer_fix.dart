// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Replaces `Expanded(child: SizedBox())` / empty `Container()` with [Spacer],
/// preserving `flex` and `key` when present.
class ReplaceExpandedEmptyChildWithSpacerFix extends SaropaFixProducer {
  ReplaceExpandedEmptyChildWithSpacerFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceExpandedEmptyChildWithSpacerFix',
    50,
    'Replace Expanded with Spacer',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    final expanded = node is InstanceCreationExpression
        ? node
        : node?.thisOrAncestorOfType<InstanceCreationExpression>();
    if (expanded == null) return;
    if (expanded.constructorName.type.name.lexeme != 'Expanded') return;

    // analyzer 13: NamedExpression → NamedArgument, .name.label.name → .name.lexeme,
    // .expression → .argumentExpression
    NamedArgument? childArg;
    final parts = <String>[];
    for (final arg in expanded.argumentList.arguments) {
      if (arg is NamedArgument) {
        final name = arg.name.lexeme;
        if (name == 'child') {
          childArg = arg;
        } else if (name == 'flex' || name == 'key') {
          parts.add('$name: ${arg.argumentExpression.toSource()}');
        }
      }
    }
    if (childArg == null) return;
    final childExpr = childArg.argumentExpression;
    if (childExpr is! InstanceCreationExpression) return;
    final childType = childExpr.constructorName.type.name.lexeme;
    if (childType != 'SizedBox' && childType != 'Container') return;
    // analyzer 13: NamedExpression → NamedArgument, .name.label.name → .name.lexeme
    final hasNestedChild = childExpr.argumentList.arguments.any(
      (e) => e is NamedArgument && e.name.lexeme == 'child',
    );
    if (hasNestedChild) return;

    final buffer = StringBuffer('Spacer(');
    if (parts.isNotEmpty) {
      buffer.write(parts.join(', '));
      buffer.write(', ');
    }
    buffer.write(')');

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(expanded.offset, expanded.length),
        buffer.toString(),
      );
    });
  }
}
