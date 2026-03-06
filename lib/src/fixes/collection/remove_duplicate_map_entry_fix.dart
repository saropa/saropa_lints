// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Remove duplicate map literal entry.
///
/// Matches [AvoidDuplicateMapKeysRule]. Deletes the entire duplicate entry.
///
/// **For developers:** Extends range to include preceding/trailing comma and newline/whitespace.
class RemoveDuplicateMapEntryFix extends SaropaFixProducer {
  RemoveDuplicateMapEntryFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeDuplicateMapEntryFix',
    50,
    'Remove duplicate map entry',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final entry = node.thisOrAncestorOfType<MapLiteralEntry>();
    if (entry == null) return;

    final content = unitResult.content;
    int start = entry.offset;
    int end = entry.end;

    // Include preceding comma and whitespace
    if (start > 0) {
      int i = start - 1;
      while (i >= 0 &&
          (content[i] == ' ' || content[i] == '\t' || content[i] == '\n')) {
        i--;
      }
      if (i >= 0 && content[i] == ',') {
        while (i > 0 && (content[i - 1] == ' ' || content[i - 1] == '\t')) {
          i--;
        }
        start = i;
      }
    }
    if (end < content.length) {
      int i = end;
      while (i < content.length && (content[i] == ' ' || content[i] == '\t')) {
        i++;
      }
      if (i < content.length && content[i] == ',') {
        i++;
        while (
            i < content.length && (content[i] == ' ' || content[i] == '\t')) {
          i++;
        }
        end = i;
      }
    }

    await builder.addDartFileEdit(file, (b) {
      b.addDeletion(SourceRange(start, end - start));
    });
  }
}
