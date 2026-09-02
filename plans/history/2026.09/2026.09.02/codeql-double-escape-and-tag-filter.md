# CodeQL #19 Double-Unescape Fix + CodeQL #20 Tag Filter Fix

Two CodeQL security code-scanning alerts addressed in the VS Code extension.

## Finish Report (2026-09-02)

### Defect 1 — Double-unescape in HTML entity decoder (CodeQL #19, CWE-116)

`decodeHtmlEntities()` in `pubdev-changelog.ts` decoded `&amp;` before other entities.
This caused double-encoded sequences like `&amp;lt;` to be decoded in two steps
(`&amp;lt;` → `&lt;` → `<`) instead of stopping at the intended literal `&lt;`.

**Fix:** Moved the `&amp;` → `&` replacement to the last position in the chain, so it
cannot produce sequences that subsequent replacements consume. The existing comment
claiming safety was incorrect and replaced with an accurate explanation referencing
CWE-116.

**Test:** Added regression test "should not double-unescape entities (CodeQL #19)" that
feeds `&amp;lt;T&amp;gt;` through the parser and asserts the output contains the
literal `&lt;T&gt;`, not `<T>`. Registered the previously-unregistered
`pubdev-changelog.test.ts` in both `tsconfig.test.json` and the mocha runner in
`package.json`.

### Defect 2 — Case-sensitive script-tag regex (CodeQL #20)

`normalizeForSnapshot()` in `snapshot-harness.ts` used a case-sensitive regex to strip
`<script>` block contents. While this is test-only code processing self-generated HTML
(not a security surface), the missing `i` flag is objectively incorrect — upper-case
`<SCRIPT>` tags would pass through un-normalized.

**Fix:** Added the `i` flag to the script-stripping regex pattern.

### Code review notes (not addressed — separate session's work)

The uncommitted working tree includes system health monitor changes from a concurrent
session. Code review found several issues in that code:

- `cleanupCommand.ts` and `processMonitor.ts` report `totalRssBytes` (all Dart
  processes) as the memory freed by killing only orphaned daemons — overstates savings.
- `en.json` uses `process(es)` literal instead of proper i18n plural handling.
- Orphan pid union logic duplicated across 4 call sites with inconsistent dedup.
- `onMemoryPressureChange` disposes daemon mid-scan without waiting for in-flight
  requests.
- Command palette title still says "Flutter Daemons" but now kills scan daemons too.

These findings belong to the session that authored those changes.

### Files changed (this task only)

| File | Change |
|------|--------|
| `extension/src/vibrancy/services/pubdev-changelog.ts` | Entity decode order: `&amp;` last |
| `extension/src/test/views/snapshots/snapshot-harness.ts` | Added `i` flag to script regex |
| `extension/src/test/vibrancy/services/pubdev-changelog.test.ts` | Double-unescape regression test |
| `extension/tsconfig.test.json` | Registered test in compilation |
| `extension/package.json` | Added test to mocha runner |
| `CHANGELOG.md` | Entries under `[15.2.9] — Unreleased` |
