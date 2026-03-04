// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Remove default or wildcard case from switch.
///
/// Matches [AvoidWildcardCasesWithEnumsRule] and [AvoidWildcardCasesWithSealedClassesRule].
class RemoveWildcardOrDefaultCaseFix extends SaropaFixProducer {
  RemoveWildcardOrDefaultCaseFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeWildcardOrDefaultCase',
    50,
    'Remove default/wildcard case',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final AstNode? toDelete =
        node.thisOrAncestorOfType<SwitchDefault>() ??
        node.thisOrAncestorOfType<SwitchExpressionCase>();
    if (toDelete == null) return;

    final content = unitResult.content;
    int start = toDelete.offset;
    int end = toDelete.end;

    // Include preceding comma and whitespace for switch expression cases
    if (start > 0) {
      int i = start - 1;
      while (i >= 0 && (content[i] == ' ' || content[i] == '\t' || content[i] == '\n' || content[i] == '\r')) {
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
