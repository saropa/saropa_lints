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

    if (node is NamedExpression && node.name.label.name == 'shrinkWrap') {
      final expr = node.expression;
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
      if (arg is! NamedExpression) continue;
      if (arg.name.label.name != 'shrinkWrap') continue;
      final expr = arg.expression;
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
