// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Converts a `///` DartDoc comment on a private declaration into
/// a plain `//` comment.
///
/// Matches `NoInternalMethodDocsRule`, which reports the [Comment] node
/// itself (the doc comment attached to a private method, function, or
/// constructor). Private members are never published by dartdoc, so the
/// fix downgrades each `///` line to `//` rather than deleting the
/// explanatory text — the content is still useful as an implementation
/// comment, it just should not masquerade as public API documentation.
class NoInternalMethodDocsFix extends SaropaFixProducer {
  NoInternalMethodDocsFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.noInternalMethodDocs',
    50,
    'Convert to a regular comment',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final AstNode? node = coveringNode;
    if (node == null) return;

    // The rule reports on the Comment node directly, but the fix also
    // tolerates being invoked from a child token/node inside it.
    final Comment? comment = node is Comment
        ? node
        : node.thisOrAncestorOfType<Comment>();
    if (comment == null) return;

    // Every DartDoc line token starts with exactly `///`. Deleting just the
    // FIRST slash turns the triple-slash prefix into a plain `//`, leaving
    // the rest of the line (including any space after the slashes)
    // untouched. Deleting two characters instead of one would strip the
    // prefix down to a single `/`, which is not a valid comment marker.
    await builder.addDartFileEdit(file, (b) {
      for (final Token token in comment.tokens) {
        final String lexeme = token.lexeme;
        if (!lexeme.startsWith('///')) continue;
        b.addSimpleReplacement(SourceRange(token.offset, 1), '');
      }
    });
  }
}
