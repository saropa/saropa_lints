// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Convert to single quotes
class ConvertToSingleQuotesFix extends SaropaFixProducer {
  ConvertToSingleQuotesFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.convertToSingleQuotesFix',
    50,
    'Convert to single quotes',
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

    // Only convert double-quoted strings to single-quoted
    final source = target.toSource();
    if (!source.startsWith('"')) return;

    final value = target.value;
    // Skip strings containing single quotes (would need escaping)
    if (value.contains("'")) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(target.offset, target.length),
        "'$value'",
      );
    });
  }
}
