# Fix `always_put_doc_comments_before_annotations` false-negative

The `_findMisplacedDocComment` helper in `stylistic_additional_rules.dart` failed to detect doc comments placed after annotations, causing false negatives for the `always_put_doc_comments_before_annotations` rule.

## Finish Report (2026-09-03)

### Root cause

The original implementation assumed that `AnnotatedNode.documentationComment` returns `null` when a `///` block is placed after annotations. This assumption was incorrect — the analyzer's `_AnnotatedNodeMixin` (verified against `package:analyzer` 12.1.0) populates `documentationComment` regardless of position relative to annotations.

With the early-return `if (node.documentationComment != null) return null;`, the function always returned `null` for nodes with doc comments, regardless of placement — making the rule unable to flag the exact scenario it was designed to catch. The token-walking loop below the guard was unreachable dead code.

### Fix

Replaced the token-walking approach with a direct offset comparison: compare `doc.offset` against `firstAnnotation.offset`. If the doc comment starts after the first annotation, it is misplaced. Renamed the function from `_findMisplacedDocComment` to `findMisplacedDocComment` with `@visibleForTesting` to enable direct behavioral testing.

### Quick fix added

New `MoveDocCommentBeforeAnnotationsFix` auto-moves misplaced `///` doc comments above all annotations with correct indentation. Uses `lineInfo`-based line boundary detection (not manual character scanning) for CRLF/tab-safe deletion range computation. Calls `findMisplacedDocComment()` directly — single source of truth, no duplicated detection logic. Supports bulk "Fix All" application via `CorrectionApplicability.acrossFiles`.

### Changes

- `lib/src/rules/stylistic/stylistic_additional_rules.dart` — rewrote `findMisplacedDocComment` with offset comparison, added `@visibleForTesting` + `import 'package:meta/meta.dart'`, registered `MoveDocCommentBeforeAnnotationsFix` via `fixGenerators`, fixed import ordering.
- `lib/src/fixes/stylistic_additional/move_doc_comment_before_annotations_fix.dart` — new quick fix that deletes the full line(s) of the misplaced doc comment via `LineInfo`-based boundaries and reinserts before the first annotation.
- `test/rules/stylistic/stylistic_additional_rules_test.dart` — 9 new behavioral tests (after-annotation, between-annotation, before-annotation, no-annotation, no-doc-comment, top-level function, class-level, field-level, multi-line doc comment). Added `_MisplacedDocCollector` visitor with all 9 `AnnotatedNode` subtypes. Added `ignore_for_file: deprecated_member_use` with why-comment.
- `CHANGELOG.md` — added Fixed + Added entries under `[15.2.10] — Unreleased`.
- `plans/history/2026.09/2026.09.03/fix_doc_comment_detection.md` — this report.

### Verification

- `dart test test/rules/stylistic/stylistic_additional_rules_test.dart` — 61 tests passed (9 new behavioral).
- `dart test test/scan/rule_quick_fix_presence_test.dart` — 201 tests passed.
- `dart test test/integrity/` — 2706 tests passed.
- Code review (medium, 8 angles) — all convention violations addressed in hardening pass: function length (compute() split to 42 lines), tab handling (lineInfo-based), import order, test visitor completeness, single-source-of-truth for detection logic.
