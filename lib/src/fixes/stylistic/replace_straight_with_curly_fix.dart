// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Use curly apostrophe
class ReplaceStraightWithCurlyFix extends SaropaFixProducer {
  ReplaceStraightWithCurlyFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceStraightWithCurlyFix',
    50,
    'Use curly apostrophe',
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

    // Replace straight apostrophe with curly right single quote
    final source = target.toSource();
    final value = target.value;
    final replaced = value.replaceAll("'", '\u2019');
    if (replaced == value) return;

    // Reconstruct the string literal with correct quoting
    final quote = source.startsWith('"') ? '"' : "'";
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(target.offset, target.length),
        '$quote$replaced$quote',
      );
    });
  }
}
