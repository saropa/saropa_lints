// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Inserts `textBaseline: TextBaseline.alphabetic` for Row/Column/Flex when baseline alignment is used.
class AddColumnTextBaselineFix extends SaropaFixProducer {
  AddColumnTextBaselineFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addColumnTextBaselineFix',
    50,
    'Add textBaseline: TextBaseline.alphabetic',
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
      if (arg is NamedExpression && arg.name.label.name == 'textBaseline') {
        return;
      }
    }

    final insertOffset = ice.argumentList.leftParenthesis.end;
    const insertion = 'textBaseline: TextBaseline.alphabetic, ';

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(insertOffset, insertion);
    });
  }
}
