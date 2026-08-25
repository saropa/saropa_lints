// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Inserts `mainAxisSize: MainAxisSize.min` into a Column (dialog overflow rule).
class AddMainAxisSizeMinFix extends SaropaFixProducer {
  AddMainAxisSizeMinFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addMainAxisSizeMinFix',
    50,
    'Add mainAxisSize: MainAxisSize.min',
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
      if (arg is NamedExpression && arg.name.label.name == 'mainAxisSize') {
        return;
      }
    }

    final insertOffset = ice.argumentList.leftParenthesis.end;
    const insertion = 'mainAxisSize: MainAxisSize.min, ';

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(insertOffset, insertion);
    });
  }
}
