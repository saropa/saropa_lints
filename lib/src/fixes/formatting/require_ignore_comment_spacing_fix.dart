// ignore_for_file: depend_on_referenced_packages

import '../../native/saropa_fix.dart';

/// Quick fix: Add space after colon in // ignore: or // ignore_for_file: comments.
class RequireIgnoreCommentSpacingFix extends SaropaFixProducer {
  RequireIgnoreCommentSpacingFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.requireIgnoreCommentSpacingFix',
    50,
    'Add space after colon',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final content = unitResult.content;
    if (content.isEmpty) return;

    // Prefer the diagnostic range (comment token) so we fix the right occurrence.
    final int start = node.offset;
    final int length = node.length;
    final int end = (start + length).clamp(0, content.length);
    int? insertOffset;
    if (length > 0 && length < 200) {
      insertOffset = _colonOffsetInSlice(content, start, end);
    }
    insertOffset ??= _findFirstMissingSpaceOffset(content);

    if (insertOffset == null) return;
    // Capture so closure sees non-null int without using ! (avoids avoid_null_assertion).
    final offset = insertOffset;

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleInsertion(offset, ' ');
    });
  }

  /// Finds the offset (after the colon) in content`start:end` for ignore directives.
  static int? _colonOffsetInSlice(String content, int start, int end) {
    if (start >= end || start < 0) return null;
    final slice = content.substring(start, end);
    const prefixes = ['// ignore:', '// ignore_for_file:'];
    for (final prefix in prefixes) {
      final idx = slice.indexOf(prefix);
      if (idx >= 0) {
        final afterColon = start + idx + prefix.length;
        if (afterColon < content.length) {
          final next = content[afterColon];
          if (next != ' ' && next != '\t') return afterColon;
        }
        return null;
      }
    }
    return null;
  }

  /// Returns the first offset in the file where a space should be inserted.
  static int? _findFirstMissingSpaceOffset(String content) {
    const patterns = ['// ignore:', '// ignore_for_file:'];
    for (final prefix in patterns) {
      int start = 0;
      while (true) {
        final idx = content.indexOf(prefix, start);
        if (idx < 0) break;
        final afterPrefix = idx + prefix.length;
        if (afterPrefix < content.length) {
          final next = content[afterPrefix];
          if (next != ' ' && next != '\t' && next != '\r' && next != '\n') {
            return afterPrefix;
          }
        }
        start = afterPrefix;
      }
    }
    return null;
  }
}
