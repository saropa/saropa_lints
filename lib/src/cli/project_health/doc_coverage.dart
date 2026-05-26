/// Public-API documentation coverage: the fraction of public declarations
/// (functions, classes, public methods, public fields) carrying a `///` doc
/// comment. Parsed AST, single pass; scope is the common public surface (enums/
/// mixins/extensions are out of v1 scope). Returns null when there is no public
/// API to document.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../analyzer_compat.dart';

/// Computes documented/public for [unit], or null when nothing public exists.
double? docCoverageOf(CompilationUnit unit) {
  final visitor = _DocVisitor();
  unit.visitChildren(visitor);
  if (visitor.publicCount == 0) return null;
  return visitor.documentedCount / visitor.publicCount;
}

class _DocVisitor extends RecursiveAstVisitor<void> {
  int publicCount = 0;
  int documentedCount = 0;

  void _count(String name, bool hasDoc) {
    if (name.startsWith('_')) return; // private API needs no public docs
    publicCount++;
    if (hasDoc) documentedCount++;
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _count(node.name.lexeme, node.documentationComment != null);
    node.visitChildren(this);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _count(node.nameToken.lexeme, node.documentationComment != null);
    node.visitChildren(this); // count public members too
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _count(node.name.lexeme, node.documentationComment != null);
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    for (final v in node.fields.variables) {
      _count(v.name.lexeme, node.documentationComment != null);
    }
  }
}
