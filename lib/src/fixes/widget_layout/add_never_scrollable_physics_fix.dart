// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Inserts `physics: const NeverScrollableScrollPhysics(),` into a scrollable.
class AddNeverScrollablePhysicsFix extends SaropaFixProducer {
  AddNeverScrollablePhysicsFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addNeverScrollablePhysicsFix',
    50,
    'Add NeverScrollableScrollPhysics',
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

    for (final arg in ice.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'physics') {
        return;
      }
    }

    final insertOffset = ice.argumentList.leftParenthesis.end;
    const insertion = 'physics: const NeverScrollableScrollPhysics(), ';

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(insertOffset, insertion);
    });
  }
}
