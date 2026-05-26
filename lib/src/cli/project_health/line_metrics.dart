/// Memory-safe line classifier for the size scanner.
///
/// Splits source into code / comment / blank counts while tracking state that
/// spans lines (nested block comments, multiline triple-quoted strings) and
/// ignoring comment markers that appear INSIDE string literals — so
/// `final url = 'https://x';` counts as code, not comment, and `final s = '/*';`
/// does not falsely open a block comment. Operates on one file's content at a
/// time; the caller reads, counts, and discards (no all-files cache).
library;

import 'dart:convert';

/// Per-line classification result.
enum LineCategory { code, comment, blank }

/// Immutable tally returned by [countLines].
class LineCounts {
  const LineCounts({
    required this.total,
    required this.code,
    required this.comment,
    required this.blank,
  });

  final int total;
  final int code;
  final int comment;
  final int blank;
}

/// Stateful classifier: feed lines in source order so block-comment depth and
/// open multiline strings carry across line boundaries.
class LineClassifier {
  /// Nesting depth of `/* */` (Dart block comments nest, so this is a count,
  /// not a bool — `/* /* */ */` is one balanced comment).
  int _blockDepth = 0;

  /// The active triple-quote delimiter (`'''` or `"""`) when inside a
  /// multiline string, else null. Non-triple strings cannot span lines in Dart.
  String? _triple;

  /// Classifies [line] and advances cross-line state.
  LineCategory classify(String line) {
    final n = line.length;
    var i = 0;
    var sawCode = false;
    var sawComment = false;

    // Continue a multiline string opened on a previous line: its content is
    // part of a code statement, so the line reads as code.
    if (_triple != null) {
      final close = line.indexOf(_triple!);
      if (close < 0) return LineCategory.code;
      i = close + _triple!.length;
      sawCode = true;
    }

    while (i < n) {
      if (_blockDepth > 0) {
        sawComment = true;
        i = _advanceBlock(line, i);
        continue;
      }
      final c = line[i];
      if (c == ' ' || c == '\t' || c == '\r') {
        i++;
        continue;
      }
      if (c == '/' && i + 1 < n && line[i + 1] == '/') {
        sawComment = true;
        break; // line comment runs to end of line
      }
      if (c == '/' && i + 1 < n && line[i + 1] == '*') {
        _blockDepth++;
        sawComment = true;
        i += 2;
        continue;
      }
      final raw =
          c == 'r' && i + 1 < n && (line[i + 1] == "'" || line[i + 1] == '"');
      final quoteIndex = raw ? i + 1 : i;
      final q = line[quoteIndex];
      if (q == "'" || q == '"') {
        sawCode = true;
        i = _consumeString(line, quoteIndex, q, raw);
        continue;
      }
      sawCode = true;
      i++;
    }

    if (sawCode) return LineCategory.code;
    if (sawComment) return LineCategory.comment;
    return LineCategory.blank;
  }

  /// Scans inside a block comment from [i], honoring nesting. Returns the index
  /// after the comment closed, or [line.length] if the line ends still inside.
  int _advanceBlock(String line, int i) {
    final n = line.length;
    while (i < n) {
      if (line[i] == '*' && i + 1 < n && line[i + 1] == '/') {
        _blockDepth--;
        i += 2;
        if (_blockDepth == 0) return i;
      } else if (line[i] == '/' && i + 1 < n && line[i + 1] == '*') {
        _blockDepth++;
        i += 2;
      } else {
        i++;
      }
    }
    return n;
  }

  /// Consumes a string literal starting at the opening quote [qi]. Handles
  /// triple-quoted (possibly multiline) and escapes (skipped when [raw]).
  /// Returns the index after the closing quote, or sets [_triple] and returns
  /// [line.length] when a triple string runs past the line.
  int _consumeString(String line, int qi, String q, bool raw) {
    final n = line.length;
    final triple = q * 3;
    if (line.startsWith(triple, qi)) {
      final close = line.indexOf(triple, qi + 3);
      if (close < 0) {
        _triple = triple;
        return n;
      }
      return close + 3;
    }
    var i = qi + 1;
    while (i < n) {
      final ch = line[i];
      if (!raw && ch == r'\') {
        i += 2; // skip the escaped char
        continue;
      }
      if (ch == q) return i + 1;
      i++;
    }
    return n; // unterminated on this line (best effort)
  }
}

/// Counts code / comment / blank lines in [content].
///
/// Uses [LineSplitter] so a trailing newline does not inflate the line count
/// (e.g. `"a\n"` is one line, not two).
LineCounts countLines(String content) {
  final lines = const LineSplitter().convert(content);
  final classifier = LineClassifier();
  var code = 0;
  var comment = 0;
  var blank = 0;
  for (final line in lines) {
    switch (classifier.classify(line)) {
      case LineCategory.code:
        code++;
      case LineCategory.comment:
        comment++;
      case LineCategory.blank:
        blank++;
    }
  }
  return LineCounts(
    total: lines.length,
    code: code,
    comment: comment,
    blank: blank,
  );
}
