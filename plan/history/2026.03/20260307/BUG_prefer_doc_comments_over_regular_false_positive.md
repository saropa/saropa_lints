# Bug: `prefer_doc_comments_over_regular` false positive on section-header comments

**Status:** Fixed in v6
**Rule:** `prefer_doc_comments_over_regular` (v5 → v6)
**Severity:** False positive — flags valid code that should not trigger
**Plugin version:** Fixed in saropa_lints v8.0.9+

## Problem

The rule flagged section-header comments (organizational dividers) as needing `///` doc-comment syntax, even though these comments are not documenting a specific public API member.

## Root cause

The rule's `_checkPrecedingComment` method walked preceding comments one at a time without context awareness. It could not detect:
1. Visual divider lines (`// -----`, `// =====`)
2. Section-header text sandwiched between dividers
3. Comments separated from declarations by a blank line

## Fix (v6)

Three heuristics added to `_checkPrecedingComment`:

1. **Blank line gap detection** — uses `context.lineInfo` to check if there is a blank line between the last comment and the declaration token. If so, all preceding comments are skipped.
2. **Divider line detection** — regex `^(.)\1{2,}$` identifies lines of 3+ repeated characters (e.g., `---`, `===`, `***`).
3. **Section header detection** — comments adjacent to divider lines in the preceding comments chain are skipped as section headers.

Refactored into three methods (`_checkPrecedingComment`, `_findDividerIndices`, `_findDocLikeComment`) to keep each under 50 lines.
