// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Remove duplicate switch case (or switch expression case).
///
/// Matches [AvoidDuplicateSwitchCaseConditionsRule]. Deletes the entire
/// duplicate case so the switch is valid.
///
/// **For developers:** Extends range to include preceding/trailing comma and whitespace.
class RemoveDuplicateSwitchCaseFix extends SaropaFixProducer {
  RemoveDuplicateSwitchCaseFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeDuplicateSwitchCaseFix',
    50,
    'Remove duplicate case',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // Reported on expression (SwitchCase) or pattern (SwitchExpressionCase).
    final AstNode? toDelete =
        node.thisOrAncestorOfType<SwitchCase>() ??
        node.thisOrAncestorOfType<SwitchExpressionCase>();
    if (toDelete == null) return;

    final content = unitResult.content;
    int start = toDelete.offset;
    int end = toDelete.end;

    // Include preceding comma and whitespace for switch cases
    if (start > 0) {
      int i = start - 1;
      while (i >= 0 && (content[i] == ' ' || content[i] == '\t')) {
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
