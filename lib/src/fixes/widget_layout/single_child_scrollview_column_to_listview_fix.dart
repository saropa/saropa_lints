// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// When a [SingleChildScrollView] wraps only a [Column] with `children:`,
/// replaces the pair with `ListView(children: ...)` (same child list).
class SingleChildScrollViewColumnToListViewFix extends SaropaFixProducer {
  SingleChildScrollViewColumnToListViewFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.singleChildScrollViewColumnToListViewFix',
    50,
    'Replace with ListView',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    final scroll = node is InstanceCreationExpression
        ? node
        : node?.thisOrAncestorOfType<InstanceCreationExpression>();
    if (scroll == null) return;
    if (scroll.constructorName.type.name.lexeme != 'SingleChildScrollView') {
      return;
    }

    InstanceCreationExpression? column;
    for (final arg in scroll.argumentList.arguments) {
      if (arg is! NamedExpression) continue;
      if (arg.name.label.name != 'child') continue;
      final ex = arg.expression;
      if (ex is InstanceCreationExpression &&
          ex.constructorName.type.name.lexeme == 'Column') {
        column = ex;
      }
      break;
    }
    if (column == null) return;

    ListLiteral? childrenList;
    for (final arg in column.argumentList.arguments) {
      if (arg is! NamedExpression) continue;
      if (arg.name.label.name != 'children') continue;
      final ex = arg.expression;
      if (ex is ListLiteral) childrenList = ex;
      break;
    }
    if (childrenList == null) return;

    final otherArgs = <String>[];
    for (final arg in scroll.argumentList.arguments) {
      if (arg is! NamedExpression) continue;
      final n = arg.name.label.name;
      if (n == 'child' || n == 'children') continue;
      otherArgs.add('${n}: ${arg.expression.toSource()}');
    }
    final prefix = otherArgs.isEmpty ? '' : '${otherArgs.join(', ')}, ';
    final replacement =
        'ListView($prefix children: ${childrenList.toSource()})';

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(scroll.offset, scroll.length),
        replacement,
      );
    });
  }
}
