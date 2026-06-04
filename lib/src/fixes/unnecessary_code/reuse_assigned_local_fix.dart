// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix for `prefer_reusing_assigned_local`.
///
/// Replaces a recomputed expression with the existing local variable that
/// already holds its value. The fix walks up from the diagnostic node to the
/// expression whose source matches an earlier `final`/`var` declaration in the
/// same block, then substitutes that local's name.
class ReuseAssignedLocalFix extends SaropaFixProducer {
  ReuseAssignedLocalFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.reuseAssignedLocal',
    60,
    'Reuse the existing local variable',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final block = node.thisOrAncestorOfType<Block>();
    if (block == null) return;

    // Map each local declaration's initializer source to (name, offset).
    // First declaration wins so the substitution targets the original cache.
    final Map<String, _DeclInfo> declsBySource = {};
    for (final statement in block.statements) {
      if (statement is! VariableDeclarationStatement) continue;
      for (final variable in statement.variables.variables) {
        final initializer = variable.initializer;
        if (initializer == null) continue;
        declsBySource.putIfAbsent(
          initializer.toSource(),
          () => _DeclInfo(variable.name.lexeme, initializer.offset),
        );
      }
    }
    if (declsBySource.isEmpty) return;

    // Climb from the diagnostic node to the smallest enclosing expression that
    // matches an earlier declaration. Requiring offset > the declaration's own
    // initializer prevents the fix from rewriting the declaration itself.
    Expression? target;
    String? replacement;
    for (
      AstNode? current = node;
      current != null && current != block;
      current = current.parent
    ) {
      if (current is! Expression) continue;
      final declInfo = declsBySource[current.toSource()];
      if (declInfo != null && current.offset > declInfo.offset) {
        target = current;
        replacement = declInfo.name;
        break;
      }
    }

    final resolvedTarget = target;
    final resolvedReplacement = replacement;
    if (resolvedTarget == null || resolvedReplacement == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(resolvedTarget.offset, resolvedTarget.length),
        resolvedReplacement,
      );
    });
  }
}

/// The name and source offset of a local variable declaration, used to map a
/// recomputed expression back to the local that already caches it.
class _DeclInfo {
  _DeclInfo(this.name, this.offset);

  final String name;
  final int offset;
}
