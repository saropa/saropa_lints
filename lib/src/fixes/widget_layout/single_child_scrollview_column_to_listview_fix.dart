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

    // Migrated: NamedExpression → NamedArgument, .name.label.name → .name.lexeme,
    // .expression → .argumentExpression (analyzer 13 API).
    InstanceCreationExpression? column;
    for (final arg in scroll.argumentList.arguments) {
      if (arg is! NamedArgument) continue;
      if (arg.name.lexeme != 'child') continue;
      final ex = arg.argumentExpression;
      if (ex is InstanceCreationExpression &&
          ex.constructorName.type.name.lexeme == 'Column') {
        column = ex;
      }
      break;
    }
    if (column == null) return;

    ListLiteral? childrenList;
    for (final arg in column.argumentList.arguments) {
      if (arg is! NamedArgument) continue;
      if (arg.name.lexeme != 'children') continue;
      final ex = arg.argumentExpression;
      if (ex is ListLiteral) childrenList = ex;
      break;
    }
    if (childrenList == null) return;

    final otherArgs = <String>[];
    for (final arg in scroll.argumentList.arguments) {
      if (arg is! NamedArgument) continue;
      final n = arg.name.lexeme;
      if (n == 'child' || n == 'children') continue;
      otherArgs.add('$n: ${arg.argumentExpression.toSource()}');
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
