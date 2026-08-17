// ignore_for_file: depend_on_referenced_packages

import 'dart:developer' as developer;

import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: replace a regular comment (//) with a doc comment (///).
///
/// Matches `PreferDocCommentsOverRegularRule`, which calls
/// `reporter.atOffset(offset: target.offset, length: target.length)` for the
/// offending comment token. Token diagnostics don't map to a useful AST node
/// — `coveringNode` resolves to the enclosing declaration (e.g. the `class`
/// keyword), not the comment — so this fix resolves the source span via
/// [diagnosticOffset]/[diagnosticLength] instead, matching the pattern used
/// by `PreferPeriodAfterDocFix`.
class PreferDocCommentFix extends SaropaFixProducer {
  PreferDocCommentFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferDocComment',
    50,
    'Convert to doc comment (///)',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final int? offset = diagnosticOffset;
    final int? length = diagnosticLength;
    if (offset == null || length == null || length < 2) return;

    final String source = unitResult.content;
    if (offset < 0 || offset + 2 > source.length) return;

    // Verify the target is a regular comment, not already a doc comment
    // or a block comment (`/*`), which this fix does not handle.
    final String prefix = source.substring(offset, offset + 2);
    if (prefix != '//') return;
    if (offset + 2 < source.length && source[offset + 2] == '/') return;

    if (file.isEmpty) return;

    try {
      await builder.addDartFileEdit(file, (b) {
        // Insert a `/` right after the `//` to make it `///`
        b.addSimpleReplacement(SourceRange(offset, 2), '///');
      });
    } catch (e, st) {
      developer.log(
        'PreferDocCommentFix addDartFileEdit failed',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
    }
  }
}
