// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Capitalize first letter
class CapitalizeCommentFix extends SaropaFixProducer {
  CapitalizeCommentFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.capitalizeCommentFix',
    50,
    'Capitalize first letter',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // Capitalize the first letter of the comment text
    final source = node.toSource();
    // Find the start of actual text after // or ///
    final match = RegExp(r'^(///?)\s*(\S)').firstMatch(source);
    if (match == null) return;

    final prefixGroup = match.group(1);
    final fullMatch = match.group(0);
    final firstCharGroup = match.group(2);
    if (prefixGroup == null || fullMatch == null || firstCharGroup == null) {
      return;
    }

    final prefix = source.substring(0, match.start + prefixGroup.length);
    final spacing = source.substring(
      match.start + prefixGroup.length,
      match.start + fullMatch.length - 1,
    );
    final firstChar = firstCharGroup;
    final rest = source.substring(match.start + fullMatch.length);
    final capitalized = '$prefix$spacing${firstChar.toUpperCase()}$rest';
    if (capitalized == source) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(node.offset, node.length),
        capitalized,
      );
    });
  }
}
