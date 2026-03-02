// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Add final to local variable declaration.
class PreferFinalLocalsFix extends SaropaFixProducer {
  PreferFinalLocalsFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferFinalLocalsFix',
    50,
    'Add final to local variable',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final list = node is VariableDeclarationList
        ? node
        : node.thisOrAncestorOfType<VariableDeclarationList>();
    if (list == null) return;

    if (list.keyword?.lexeme == 'final' || list.keyword?.lexeme == 'const') {
      return;
    }

    await builder.addDartFileEdit(file, (builder) {
      final Token? keyword = list.keyword;
      if (keyword != null && keyword.lexeme == 'var') {
        builder.addSimpleReplacement(
          SourceRange(keyword.offset, keyword.length),
          'final',
        );
      } else {
        builder.addSimpleInsertion(list.offset, 'final ');
      }
    });
  }
}
