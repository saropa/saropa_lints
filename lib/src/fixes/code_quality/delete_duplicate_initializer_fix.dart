// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Remove duplicate constructor field initializer.
///
/// Matches [AvoidDuplicateInitializersRule]. Deletes the duplicate
/// initializer (keeping the first occurrence).
class DeleteDuplicateInitializerFix extends SaropaFixProducer {
  DeleteDuplicateInitializerFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.deleteDuplicateInitializer',
    50,
    'Remove duplicate initializer',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final ConstructorFieldInitializer? toDelete = node
        .thisOrAncestorOfType<ConstructorFieldInitializer>();
    if (toDelete == null) return;

    final content = unitResult.content;
    int start = toDelete.offset;
    int end = toDelete.end;

    // Include preceding comma and whitespace
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

    await builder.addDartFileEdit(file, (b) {
      b.addDeletion(SourceRange(start, end - start));
    });
  }
}
