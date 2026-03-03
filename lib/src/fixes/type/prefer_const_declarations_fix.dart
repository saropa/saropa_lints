// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace final with const for constant initializer.
class PreferConstDeclarationsFix extends SaropaFixProducer {
  PreferConstDeclarationsFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferConstDeclarationsFix',
    50,
    'Use const instead of final',
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
    if (list == null || list.keyword?.lexeme != 'final') return;

    final keyword = list.keyword;
    if (keyword == null) return;
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(keyword.offset, keyword.length),
        'const',
      );
    });
  }
}
