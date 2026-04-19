// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Strip the deprecated `new ` keyword from `[new Foo]` doc
/// references so they become `[Foo]`.
///
/// Matches [DeprecatedNewInCommentReferenceRule]. The rule reports the entire
/// [Comment] node; the fix walks its tokens and replaces each `[new <name>]`
/// substring with `[<name>]`, preserving surrounding whitespace.
class DeprecatedNewInCommentReferenceFix extends SaropaFixProducer {
  DeprecatedNewInCommentReferenceFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.deprecatedNewInCommentReference',
    50,
    'Remove `new` from doc comment reference',
  );

  @override
  FixKind get fixKind => _fixKind;

  static final RegExp _newRef = RegExp(r'\[\s*new\s+([\w.]+)\s*\]');

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final AstNode? node = coveringNode;
    if (node == null) return;

    final Comment? comment = node is Comment
        ? node
        : node.thisOrAncestorOfType<Comment>();
    if (comment == null) return;

    // Collect (offset, length, replacement) edits per token so overlapping
    // ranges across tokens are impossible.
    final List<_Edit> edits = <_Edit>[];
    for (final Token token in comment.tokens) {
      final String lexeme = token.lexeme;
      for (final RegExpMatch match in _newRef.allMatches(lexeme)) {
        final String name = match.group(1) ?? '';
        if (name.isEmpty) continue;
        edits.add(
          _Edit(
            offset: token.offset + match.start,
            length: match.end - match.start,
            replacement: '[$name]',
          ),
        );
      }
    }
    if (edits.isEmpty) return;

    await builder.addDartFileEdit(file, (b) {
      for (final _Edit e in edits) {
        b.addSimpleReplacement(SourceRange(e.offset, e.length), e.replacement);
      }
    });
  }
}

class _Edit {
  _Edit({
    required this.offset,
    required this.length,
    required this.replacement,
  });
  final int offset;
  final int length;
  final String replacement;
}
