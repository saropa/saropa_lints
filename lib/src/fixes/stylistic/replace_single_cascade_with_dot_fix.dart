// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace a single-section cascade (`obj..foo()`) used as an
/// expression statement with a direct call (`obj.foo()`).
///
/// Matches `AvoidSingleCascadeInExpressionStatementsRule`, which only
/// reports when the cascade has exactly one section AND its parent is an
/// `ExpressionStatement` — both are required because in those cases the
/// returned cascade target is discarded, so no semantic change occurs from
/// switching to a regular method call. We delete one of the two dots in
/// `..` to convert `..` into `.`.
class ReplaceSingleCascadeWithDotFix extends SaropaFixProducer {
  ReplaceSingleCascadeWithDotFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceSingleCascadeWithDot',
    50,
    'Replace single cascade with direct call',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final AstNode? node = coveringNode;
    if (node == null) return;

    final CascadeExpression? cascade = node is CascadeExpression
        ? node
        : node.thisOrAncestorOfType<CascadeExpression>();
    if (cascade == null) return;
    if (cascade.cascadeSections.length != 1) return;

    // The single cascade section starts with the `..` token. Find the dot
    // immediately before the section and delete one character — this turns
    // `..add(x)` into `.add(x)` without disturbing whitespace or the call
    // arguments.
    final AstNode section = cascade.cascadeSections.first;
    final int sectionStart = section.offset;

    final String content = unitResult.content;
    if (sectionStart < 2 || sectionStart > content.length) return;
    // Sanity-check: the two characters before the section should be `..`.
    // Use codeUnitAt (avoids `substring`, which the in-tree avoid_string_substring
    // rule flags as range-unsafe even when bounds are checked).
    const int dot = 0x2E;
    if (content.codeUnitAt(sectionStart - 2) != dot) return;
    if (content.codeUnitAt(sectionStart - 1) != dot) return;

    await builder.addDartFileEdit(file, (b) {
      b.addDeletion(SourceRange(sectionStart - 1, 1));
    });
  }
}
