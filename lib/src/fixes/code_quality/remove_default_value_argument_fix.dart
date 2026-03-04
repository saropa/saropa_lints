// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Remove the named argument that passes a default value.
///
/// Matches [AvoidPassingDefaultValuesRule]. Deletes the argument
/// so the parameter uses its default.
class RemoveDefaultValueArgumentFix extends SaropaFixProducer {
  RemoveDefaultValueArgumentFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeDefaultValueArgument',
    50,
    'Remove argument (use default)',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final NamedExpression? named = node.thisOrAncestorOfType<NamedExpression>();
    if (named == null) return;

    final content = unitResult.content;
    int start = named.offset;
    int end = named.end;

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
