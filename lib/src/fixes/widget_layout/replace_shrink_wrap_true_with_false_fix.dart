// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Sets `shrinkWrap: true` to `shrinkWrap: false` for scrollable widgets.
class ReplaceShrinkWrapTrueWithFalseFix extends SaropaFixProducer {
  ReplaceShrinkWrapTrueWithFalseFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceShrinkWrapTrueWithFalseFix',
    50,
    'Set shrinkWrap to false',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // analyzer 13: NamedExpression -> NamedArgument; `.name.lexeme`
    // replaces `.name.label.name`, `.argumentExpression` replaces
    // `.expression`.
    if (node is NamedArgument && node.name.lexeme == 'shrinkWrap') {
      final expr = node.argumentExpression;
      if (expr is BooleanLiteral && expr.value) {
        await builder.addDartFileEdit(file, (builder) {
          builder.addSimpleReplacement(
            SourceRange(expr.offset, expr.length),
            'false',
          );
        });
      }
      return;
    }

    final ice = node.thisOrAncestorOfType<InstanceCreationExpression>();
    if (ice == null) return;

    for (final arg in ice.argumentList.arguments) {
      if (arg is! NamedArgument) continue;
      if (arg.name.lexeme != 'shrinkWrap') continue;
      final expr = arg.argumentExpression;
      if (expr is BooleanLiteral && expr.value) {
        await builder.addDartFileEdit(file, (builder) {
          builder.addSimpleReplacement(
            SourceRange(expr.offset, expr.length),
            'false',
          );
        });
      }
      return;
    }
  }
}
