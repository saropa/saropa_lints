// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Replaces `Column(children: [w])` / `Row(children: [w])` with `w`.
class UnwrapSingleChildColumnOrRowFix extends SaropaFixProducer {
  UnwrapSingleChildColumnOrRowFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.unwrapSingleChildColumnOrRowFix',
    50,
    'Unwrap single child',
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
    final type = ice.constructorName.type.name.lexeme;
    if (type != 'Column' && type != 'Row') return;

    for (final arg in ice.argumentList.arguments) {
      if (arg is! NamedExpression) continue;
      if (arg.name.label.name != 'children') continue;
      final list = arg.expression;
      if (list is! ListLiteral) return;
      if (list.elements.length != 1) return;
      final only = list.elements.single;
      if (only is! Expression) return;
      final src = only.toSource();

      await builder.addDartFileEdit(file, (builder) {
        builder.addSimpleReplacement(SourceRange(ice.offset, ice.length), src);
      });
      return;
    }
  }
}
