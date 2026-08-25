// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import '../../native/saropa_fix.dart';

/// Inserts `itemExtent: 56.0,` after `(` for uniform-height list rows.
///
/// Adjust the value to match your row height after applying.
class AddItemExtentPlaceholderFix extends SaropaFixProducer {
  AddItemExtentPlaceholderFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addItemExtentPlaceholderFix',
    50,
    'Add itemExtent (56.0)',
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
      if (arg is NamedExpression) {
        final n = arg.name.label.name;
        if (n == 'itemExtent' ||
            n == 'prototypeItem' ||
            n == 'itemExtentBuilder') {
          return;
        }
      }
    }

    final insertOffset = ice.argumentList.leftParenthesis.end;
    const insertion = 'itemExtent: 56.0, ';

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(insertOffset, insertion);
    });
  }
}
