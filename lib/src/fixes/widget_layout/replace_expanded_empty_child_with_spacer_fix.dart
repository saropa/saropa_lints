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

    NamedExpression? childArg;
    final parts = <String>[];
    for (final arg in expanded.argumentList.arguments) {
      if (arg is NamedExpression) {
        final name = arg.name.label.name;
        if (name == 'child') {
          childArg = arg;
        } else if (name == 'flex' || name == 'key') {
          parts.add('${name}: ${arg.expression.toSource()}');
        }
      }
    }
    if (childArg == null) return;
    final childExpr = childArg.expression;
    if (childExpr is! InstanceCreationExpression) return;
    final childType = childExpr.constructorName.type.name.lexeme;
    if (childType != 'SizedBox' && childType != 'Container') return;
    final hasNestedChild = childExpr.argumentList.arguments.any(
      (e) => e is NamedExpression && e.name.label.name == 'child',
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
