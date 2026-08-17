// ignore_for_file: depend_on_referenced_packages

import 'dart:developer' as developer;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: remove the explicit type annotation from a variable declaration.
///
/// The rule reports at the TypeAnnotation node. This fix deletes the type
/// and its trailing whitespace, leaving the declaration with inferred type.
class RemoveExplicitTypeFix extends SaropaFixProducer {
  RemoveExplicitTypeFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeExplicitType',
    50,
    'Remove explicit type annotation',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // Navigate to the TypeAnnotation node
    final AstNode? target = node is TypeAnnotation
        ? node
        : node.thisOrAncestorOfType<TypeAnnotation>();
    if (target == null) return;

    if (file.isEmpty) return;

    // Delete the type annotation and the trailing space before the variable name
    final source = unitResult.content;
    var endOffset = target.end;

    // Consume trailing whitespace (the space between type and variable name)
    while (endOffset < source.length && source[endOffset] == ' ') {
      endOffset++;
    }

    final offset = target.offset;
    final length = endOffset - offset;
    if (offset < 0 || length <= 0) return;

    try {
      await builder.addDartFileEdit(file, (b) {
        b.addDeletion(SourceRange(offset, length));
      });
    } catch (e, st) {
      developer.log(
        'RemoveExplicitTypeFix addDartFileEdit failed',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
    }
  }
}
