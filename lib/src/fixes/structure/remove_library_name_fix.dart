// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';
import '../common/replace_node_fix.dart';

/// Quick fix: Remove the name from a library directive, leaving bare `library;`.
///
/// Matches [UnnecessaryLibraryNameRule].
class RemoveLibraryNameFix extends ReplaceNodeFix {
  RemoveLibraryNameFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeLibraryName',
    50,
    "Remove library name",
  );

  @override
  FixKind get fixKind => _fixKind;

  /// Navigate from the DottedName up to the full LibraryDirective
  /// so we replace the entire directive, not just the name.
  @override
  AstNode? findTargetNode(AstNode node) =>
      node.thisOrAncestorOfType<LibraryDirective>();

  @override
  String computeReplacement(AstNode node) => 'library;';
}
