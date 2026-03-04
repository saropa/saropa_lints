// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Remove duplicate element from list/set literal.
///
/// Matches [AvoidDuplicateNumberElementsRule], [AvoidDuplicateStringElementsRule],
/// and [AvoidDuplicateObjectElementsRule]. Deletes the duplicate element and
/// its preceding or trailing comma.
class RemoveDuplicateCollectionElementFix extends SaropaFixProducer {
  RemoveDuplicateCollectionElementFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeDuplicateCollectionElement',
    50,
    'Remove duplicate element',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final element = node is Expression
        ? node
        : node.thisOrAncestorOfType<Expression>();
    if (element == null) return;

    final content = unitResult.content;
    int start = element.offset;
    int end = element.end;

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
        while (i < content.length &&
            (content[i] == ' ' || content[i] == '\t')) {
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
