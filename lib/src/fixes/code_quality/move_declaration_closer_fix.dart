// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: move a flagged declaration statement down to just before its
/// first use in the same block.
///
/// Matches `MoveVariableCloserToUsageRule`
/// (`move_variable_closer_to_its_usage`). Only offers the fix — leaving the
/// diagnostic-only path for the IDE to fall back on otherwise — when doing
/// so is provably safe:
/// - the statement declares exactly one variable (multi-variable
///   declarations, e.g. `final a = 1, b = 2;`, are left alone: the other
///   variable's own usage story could differ from the flagged one's),
/// - the first use is a direct child of the same block (mirrors the rule's
///   own guard: nothing nested in a loop/branch/closure), and
/// - no statement between the original position and the first use reads or
///   writes any identifier that also appears in the declaration's own
///   initializer. Reordering around shared state can change behavior, and
///   this fix must never silently alter semantics — a decl/use pair that
///   fails this check is left for the developer to move by hand.
class MoveDeclarationCloserFix extends SaropaFixProducer {
  MoveDeclarationCloserFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.moveDeclarationCloser',
    50,
    'Move declaration closer to its first use',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final AstNode? node = coveringNode;
    if (node == null) return;

    final VariableDeclarationStatement? declStatement = node is VariableDeclarationStatement
        ? node
        : node.thisOrAncestorOfType<VariableDeclarationStatement>();
    if (declStatement == null) return;
    // Multi-variable declarations are left alone in this first version — the
    // other declared variable's own use pattern is not accounted for here.
    if (declStatement.variables.variables.length != 1) return;

    final AstNode? parent = declStatement.parent;
    if (parent is! Block) return;
    final Block block = parent;

    final VariableDeclaration decl = declStatement.variables.variables.first;
    final String name = decl.name.lexeme;

    final List<Statement> statements = block.statements;
    final int declIndex = statements.indexOf(declStatement);
    if (declIndex < 0) return;

    // Find the first direct-child-of-block statement that references `name`,
    // mirroring the rule's own `_FirstUsageVisitor` + direct-child guard.
    Statement? useStatement;
    for (int i = declIndex + 1; i < statements.length; i++) {
      final _ReferencesNameVisitor finder = _ReferencesNameVisitor(name);
      statements[i].accept(finder);
      if (finder.found) {
        useStatement = statements[i];
        break;
      }
    }
    if (useStatement == null) return;
    final int useIndex = statements.indexOf(useStatement);
    if (useIndex <= declIndex) return;

    // Safety guard: refuse to move past any intervening statement that
    // shares an identifier with this declaration's own initializer.
    final Set<String> initializerNames = _collectIdentifierNames(
      decl.initializer,
    );
    if (initializerNames.isNotEmpty) {
      for (int i = declIndex + 1; i < useIndex; i++) {
        final Set<String> siblingNames = _collectIdentifierNames(
          statements[i],
        );
        if (siblingNames.intersection(initializerNames).isNotEmpty) return;
      }
    }

    final String declSource = declStatement.toSource();
    final String indent = getLineIndent(useStatement);

    // Deletion range spans from the declaration's own offset up to the
    // start of the next statement, so the blank line it leaves behind is
    // removed along with it rather than left as stray whitespace.
    final int deletionEnd = declIndex + 1 < statements.length
        ? statements[declIndex + 1].offset
        : declStatement.end;

    await builder.addDartFileEdit(file, (b) {
      b.addDeletion(
        SourceRange(declStatement.offset, deletionEnd - declStatement.offset),
      );
      b.addSimpleInsertion(useStatement!.offset, '$declSource\n$indent');
    });
  }

  Set<String> _collectIdentifierNames(AstNode? node) {
    if (node == null) return const <String>{};
    final _IdentifierCollector collector = _IdentifierCollector();
    node.accept(collector);
    return collector.names;
  }
}

/// Stops at the first `SimpleIdentifier` matching [name] anywhere within the
/// visited subtree, including nested scopes — a reference in any position
/// disqualifies the statement from being skipped over by [MoveDeclarationCloserFix].
class _ReferencesNameVisitor extends RecursiveAstVisitor<void> {
  _ReferencesNameVisitor(this.name);

  final String name;
  bool found = false;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (!found && node.name == name) {
      found = true;
    }
    super.visitSimpleIdentifier(node);
  }
}

/// Collects every `SimpleIdentifier` name referenced anywhere within the
/// visited subtree, read or write alike — used to detect potential shared
/// state between the moved declaration's initializer and an intervening
/// statement.
class _IdentifierCollector extends RecursiveAstVisitor<void> {
  final Set<String> names = <String>{};

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    names.add(node.name);
    super.visitSimpleIdentifier(node);
  }
}
