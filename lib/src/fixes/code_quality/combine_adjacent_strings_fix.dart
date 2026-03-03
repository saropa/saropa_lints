// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/replace_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Combine adjacent string literals into one.
///
/// Matches [AvoidAdjacentStringsRule]. Replaces the node with a single
/// double-quoted string literal. Only combines when all parts are
/// [SimpleStringLiteral]; if any part is [StringInterpolation], returns
/// [node.toSource] unchanged to avoid corrupting interpolations.
///
/// **For developers:** Escapes backslash and double-quote in the combined value.
class CombineAdjacentStringsFix extends ReplaceNodeFix {
  CombineAdjacentStringsFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.combineAdjacentStringsFix',
    50,
    'Combine into single string',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  String computeReplacement(AstNode node) {
    if (node is! AdjacentStrings) return node.toSource();
    final parts = <String>[];
    for (final StringLiteral s in node.strings) {
      if (s is SimpleStringLiteral) {
        parts.add(s.value);
      } else {
        return node.toSource();
      }
    }
    final combined = parts.join();
    return '"${combined.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
  }
}
