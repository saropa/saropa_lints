// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Increase font size to minimum accessible value (12).
class IncreaseFontSizeFix extends SaropaFixProducer {
  IncreaseFontSizeFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.increaseFontSize',
    50,
    'Increase font size to 12',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // The rule reports on the InstanceCreationExpression (TextStyle(...))
    final creation = node is InstanceCreationExpression
        ? node
        : node.thisOrAncestorOfType<InstanceCreationExpression>();
    if (creation == null) return;

    // Find the fontSize argument
    for (final arg in creation.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'fontSize') {
        await builder.addDartFileEdit(file, (builder) {
          builder.addSimpleReplacement(
            SourceRange(arg.expression.offset, arg.expression.length),
            '12',
          );
        });
        return;
      }
    }
  }
}
