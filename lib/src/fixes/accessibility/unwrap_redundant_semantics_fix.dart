// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Replaces redundant `Semantics(label: ..., child: Image(..., semanticLabel: ...))`
/// with the inner [Image] only (matches [AvoidRedundantSemanticsRule] intent).
class UnwrapRedundantSemanticsFix extends SaropaFixProducer {
  UnwrapRedundantSemanticsFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.unwrapRedundantSemanticsFix',
    50,
    'Remove redundant Semantics wrapper',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    final ConstructorName? ctorName = node is ConstructorName
        ? node
        : node?.thisOrAncestorOfType<ConstructorName>();
    if (ctorName == null) return;

    final parent = ctorName.parent;
    if (parent is! InstanceCreationExpression) return;
    final semantics = parent;
    if (semantics.constructorName.type.name.lexeme != 'Semantics') return;

    // analyzer 13: NamedExpression renamed to NamedArgument; name is a
    // Token (.lexeme) and the value getter is now .argumentExpression.
    NamedArgument? childArg;
    for (final arg in semantics.argumentList.arguments) {
      if (arg is NamedArgument && arg.name.lexeme == 'child') {
        childArg = arg;
        break;
      }
    }
    if (childArg == null) return;

    final childSource = childArg.argumentExpression.toSource();

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(semantics.offset, semantics.length),
        childSource,
      );
    });
  }
}
