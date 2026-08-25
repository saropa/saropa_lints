// ignore_for_file: depend_on_referenced_packages

import 'dart:developer' as developer;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Reusable quick fix: delete a named argument from its argument list, together
/// with the separating comma, so the remaining arguments stay syntactically
/// valid.
///
/// Used by rules that flag a redundant or disallowed named argument (e.g.
/// `avoid_icon_size_override` removing `size:`, `avoid_riverpod_string_provider_name`
/// removing `name:`). The rule must report at the [NamedExpression] node.
///
/// Comma handling: if a trailing comma follows the argument it is consumed; if
/// only a leading comma exists (the argument is last) that comma is consumed
/// instead; a sole argument with no comma is removed on its own. `dart format`
/// tidies any residual whitespace.
class RemoveNamedArgumentFix extends SaropaFixProducer {
  RemoveNamedArgumentFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeNamedArgument',
    50,
    'Remove the argument',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final named = node is NamedExpression
        ? node
        : node.thisOrAncestorOfType<NamedExpression>();
    if (named == null) return;
    if (named.parent is! ArgumentList) return;

    int start = named.offset;
    int end = named.end;

    // Prefer consuming a trailing comma; fall back to a leading one so the
    // surviving arguments are never left with a dangling separator.
    final Token? next = named.endToken.next;
    if (next != null && next.type == TokenType.COMMA) {
      end = next.end;
    } else {
      final Token? prev = named.beginToken.previous;
      if (prev != null && prev.type == TokenType.COMMA) {
        start = prev.offset;
      }
    }

    if (start < 0 || end <= start) return;

    try {
      await builder.addDartFileEdit(file, (b) {
        b.addDeletion(SourceRange(start, end - start));
      });
    } catch (e, st) {
      developer.log(
        'RemoveNamedArgumentFix addDartFileEdit failed',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
    }
  }
}
