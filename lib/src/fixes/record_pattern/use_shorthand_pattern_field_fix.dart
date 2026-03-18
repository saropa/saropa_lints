// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace `fieldName: fieldName` with `:fieldName` shorthand.
class UseShorthandPatternFieldFix extends SaropaFixProducer {
  UseShorthandPatternFieldFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.useShorthandPatternField',
    50,
    'Use shorthand pattern field',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final field = node is PatternField
        ? node
        : node.thisOrAncestorOfType<PatternField>();
    if (field == null) return;

    final fieldName = field.name?.name?.lexeme;
    if (fieldName == null) return;

    // Replace the entire "fieldName: fieldName" with ":fieldName"
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(field.offset, field.length),
        ':$fieldName',
      );
    });
  }
}
