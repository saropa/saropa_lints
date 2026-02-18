// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace with straight apostrophe
class ReplaceCurlyApostropheFix extends SaropaFixProducer {
  ReplaceCurlyApostropheFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceCurlyApostropheFix',
    50,
    'Replace with straight apostrophe',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is SimpleStringLiteral
        ? node
        : node.thisOrAncestorOfType<SimpleStringLiteral>();
    if (target == null) return;

    // Replace curly apostrophes (\u2019, \u2018) with straight apostrophe
    final source = target.toSource();
    final replaced = source.replaceAll('\u2019', "'").replaceAll('\u2018', "'");
    if (replaced == source) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(target.offset, target.length),
        replaced,
      );
    });
  }
}
