// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Remove super()
class RemoveUnnecessarySuperFix extends SaropaFixProducer {
  RemoveUnnecessarySuperFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeUnnecessarySuperFix',
    50,
    'Remove super()',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is ConstructorDeclaration
        ? node
        : node.thisOrAncestorOfType<ConstructorDeclaration>();
    if (target == null) return;

    // Remove the super() initializer from constructor
    // Find the SuperConstructorInvocation in the initializers
    for (final initializer in target.initializers) {
      if (initializer is SuperConstructorInvocation) {
        // If it's the only initializer, remove the colon too
        if (target.initializers.length == 1) {
          // Remove from the separator (:) to the initializer end
          final separator = target.separator;
          if (separator != null) {
            await builder.addDartFileEdit(file, (builder) {
              builder.addDeletion(
                SourceRange(separator.offset, initializer.end - separator.offset),
              );
            });
          }
        } else {
          // Remove this initializer and adjacent comma
          final idx = target.initializers.indexOf(initializer);
          int start;
          int end;
          if (idx > 0) {
            // Delete from end of previous initializer to end of this one
            start = target.initializers[idx - 1].end;
            end = initializer.end;
          } else {
            // First but not only: delete to start of next initializer
            start = initializer.offset;
            end = target.initializers[idx + 1].offset;
          }
          await builder.addDartFileEdit(file, (builder) {
            builder.addDeletion(SourceRange(start, end - start));
          });
        }
        return;
      }
    }
  }
}
