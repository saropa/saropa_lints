// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Remove duplicate pattern case from switch.
///
/// Matches [AvoidDuplicatePatternsRule]. Deletes the duplicate case.
class RemoveDuplicatePatternCaseFix extends SaropaFixProducer {
  RemoveDuplicatePatternCaseFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeDuplicatePatternCase',
    50,
    'Remove duplicate pattern case',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final AstNode? toDelete =
        node.thisOrAncestorOfType<SwitchExpressionCase>() ??
        node.thisOrAncestorOfType<SwitchPatternCase>();
    if (toDelete == null) return;

    final content = unitResult.content;
    int start = toDelete.offset;
    int end = toDelete.end;

    if (start > 0) {
      int i = start - 1;
      while (i >= 0 &&
          (content[i] == ' ' ||
              content[i] == '\t' ||
              content[i] == '\n' ||
              content[i] == '\r')) {
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
