// ignore_for_file: depend_on_referenced_packages

/// AST walker that dispatches every node to captured rule visitors.
///
/// Uses [GeneralizingAstVisitor] so that a single [visitNode] override
/// covers ALL node types — no risk of missing overrides when new AST
/// node types are added to the analyzer.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Walks a [CompilationUnit] dispatching each node to all `_visitors`.
///
/// [node.accept(v)] calls the correct `visitXxx` on each visitor based
/// on the node's runtime type. [node.visitChildren(this)] recurses.
class ScanWalker extends GeneralizingAstVisitor<void> {
  ScanWalker(this._visitors);

  final List<AstVisitor<void>> _visitors;

  @override
  void visitNode(AstNode node) {
    for (final v in _visitors) {
      node.accept(v);
    }
    node.visitChildren(this);
  }
}
