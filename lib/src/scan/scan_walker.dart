// ignore_for_file: depend_on_referenced_packages

/// AST walker that dispatches every node to captured rule visitors.
///
/// Uses [GeneralizingAstVisitor] so that a single [visitNode] override
/// covers ALL node types — no risk of missing overrides when new AST
/// node types are added to the analyzer.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Reports a rule visitor that threw during the walk, so the runner can name
/// the offending rule. Called at most once per visitor per walk.
typedef ScanVisitorError =
    void Function(AstVisitor<void> visitor, Object error, StackTrace stackTrace);

/// Walks a [CompilationUnit] dispatching each node to all `_visitors`.
///
/// [node.accept(v)] calls the correct `visitXxx` on each visitor based
/// on the node's runtime type. [node.visitChildren(this)] recurses.
class ScanWalker extends GeneralizingAstVisitor<void> {
  ScanWalker(this._visitors, {this.onError});

  final List<AstVisitor<void>> _visitors;

  /// Invoked when a visitor throws. When null, exceptions propagate (the
  /// historical behavior). Supplying it makes the walk resilient: a throwing
  /// rule is disabled for the rest of this walk instead of aborting the file.
  final ScanVisitorError? onError;

  /// Visitors that threw earlier in this walk. Skipped on subsequent nodes so a
  /// single buggy rule cannot derail the remaining nodes or sibling rules.
  final Set<AstVisitor<void>> _disabled = {};

  @override
  void visitNode(AstNode node) {
    for (final v in _visitors) {
      // A rule that throws on one node must not take down the whole scan: when
      // an error sink is provided, isolate the failure to that single rule.
      if (onError == null) {
        node.accept(v);
        continue;
      }
      if (_disabled.contains(v)) continue;
      try {
        node.accept(v);
      } on Object catch (e, st) {
        _disabled.add(v);
        onError!(v, e, st);
      }
    }
    node.visitChildren(this);
  }
}
