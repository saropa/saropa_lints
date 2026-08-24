// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Inserts `physics: const ClampingScrollPhysics(),` into a scrollable.
class AddClampingScrollPhysicsFix extends SaropaFixProducer {
  AddClampingScrollPhysicsFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addClampingScrollPhysicsFix',
    50,
    'Add ClampingScrollPhysics',
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
    final ice = parent;

    // analyzer 13: NamedExpression renamed to NamedArgument; name is a
    // Token (.lexeme) rather than a Label.
    for (final arg in ice.argumentList.arguments) {
      if (arg is NamedArgument && arg.name.lexeme == 'physics') {
        return;
      }
    }

    final insertOffset = ice.argumentList.leftParenthesis.end;
    const insertion = 'physics: const ClampingScrollPhysics(), ';

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(insertOffset, insertion);
    });
  }
}
