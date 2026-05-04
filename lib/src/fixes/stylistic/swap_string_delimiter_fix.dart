// ignore_for_file: depend_on_referenced_packages, avoid_string_substring

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Switch a `SimpleStringLiteral` between single and double
/// quote delimiters so escaped inner quotes are no longer needed.
///
/// Matches `AvoidEscapingInnerQuotesRule`. The rule reports only when:
/// - the string is non-raw,
/// - the current delimiter type appears escaped inside (e.g. `\'` in a
///   single-quoted string),
/// - the *opposite* delimiter does NOT already appear unescaped — meaning
///   we can swap delimiters without introducing a new escape.
/// We rewrite the literal: drop the escapes for the current delimiter,
/// and emit the same content wrapped in the opposite delimiter.
class SwapStringDelimiterFix extends SaropaFixProducer {
  SwapStringDelimiterFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.swapStringDelimiter',
    50,
    'Switch string delimiter to remove escaping',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final AstNode? node = coveringNode;
    if (node == null) return;

    final SimpleStringLiteral? literal = node is SimpleStringLiteral
        ? node
        : node.thisOrAncestorOfType<SimpleStringLiteral>();
    if (literal == null) return;
    if (literal.isRaw) return;

    final String lexeme = literal.literal.lexeme;
    if (lexeme.length < 2) return;

    // Determine current quote (single or double). Triple-quoted strings
    // start with three identical quote chars — handle them explicitly so
    // we don't truncate the body.
    final String first = lexeme[0];
    final String quote;
    final String tripleQuote;
    final bool isTriple;
    if (first == "'" || first == '"') {
      quote = first;
      tripleQuote = '$first$first$first';
      isTriple = lexeme.startsWith(tripleQuote);
    } else {
      return;
    }

    final String openDelim = isTriple ? tripleQuote : quote;
    final String closeDelim = openDelim;
    if (!lexeme.endsWith(closeDelim)) return;

    final int innerStart = openDelim.length;
    final int innerEnd = lexeme.length - closeDelim.length;
    if (innerEnd < innerStart) return;
    final String inner = lexeme.substring(innerStart, innerEnd);

    // Swap to the opposite delimiter and remove backslash escapes for the
    // *previous* delimiter (those are unnecessary in the new quoting).
    final String otherQuote = quote == "'" ? '"' : "'";
    final String otherDelim = isTriple
        ? '$otherQuote$otherQuote$otherQuote'
        : otherQuote;
    final String unescaped = inner.replaceAll('\\$quote', quote);
    final String rewritten = '$otherDelim$unescaped$otherDelim';
    if (rewritten == lexeme) return;

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(literal.offset, literal.length),
        rewritten,
      );
    });
  }
}
