// ignore_for_file: depend_on_referenced_packages, avoid_string_substring

import '../../native/saropa_fix.dart';

/// Quick fix: Append a period to the last `///` line of a doc comment whose
/// visible content does not already end with terminal punctuation.
///
/// Matches `PreferPeriodAfterDocRule`, which calls `reporter.atToken(lastToken)`
/// for the final non-empty doc-comment token. The diagnostic range therefore
/// covers exactly the offending `///` line. We resolve the source span via
/// [diagnosticOffset]/[diagnosticLength] (token-based diagnostics don't map
/// to a useful AST node — `coveringNode` returns the enclosing declaration,
/// not the token), then insert `.` after the last non-whitespace character
/// in that token. The rule already filters out endings that should not get
/// a period (code fences, `:`, `]`, `)`, `@…`, dartdoc macros).
class PreferPeriodAfterDocFix extends SaropaFixProducer {
  PreferPeriodAfterDocFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferPeriodAfterDoc',
    50,
    'Add period at end of doc comment',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    // Use diagnosticOffset/Length rather than coveringNode: the rule reports
    // at a Token, and Token positions don't survive AST coverage lookup.
    final int? offset = diagnosticOffset;
    final int? length = diagnosticLength;
    if (offset == null || length == null || length <= 0) return;

    final String content = unitResult.content;
    if (offset < 0 || offset + length > content.length) return;

    // Walk back from the end of the diagnostic span to skip any trailing
    // whitespace inside the token, so the period lands flush against the
    // last visible character (e.g. for `/// foo  ` we insert after `foo`).
    int insertAt = offset + length;
    while (insertAt > offset) {
      final int code = content.codeUnitAt(insertAt - 1);
      // 0x20 = space, 0x09 = tab. Stop at any other char.
      if (code == 0x20 || code == 0x09) {
        insertAt -= 1;
        continue;
      }
      break;
    }

    // Defensive: bail if the last char already terminates the sentence —
    // rule should have skipped this case, but a stale snapshot might not.
    if (insertAt > 0) {
      final int lastCode = content.codeUnitAt(insertAt - 1);
      // 0x2E = '.', 0x21 = '!', 0x3F = '?'.
      if (lastCode == 0x2E || lastCode == 0x21 || lastCode == 0x3F) return;
    }

    // The token includes the literal `///` prefix; if the visible content
    // is empty (just `///`) there's nothing to terminate.
    if (insertAt - offset <= 3) return;

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleInsertion(insertAt, '.');
    });
  }
}
