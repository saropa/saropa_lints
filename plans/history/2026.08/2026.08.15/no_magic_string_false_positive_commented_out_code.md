# BUG: `no_magic_string` — Appears to Flag String Literals Inside `//`-Commented-Out Code (AST-Impossible; Likely Stale-Diagnostic Offset, Not a Real Text-Scan Bug)

**Status: Closed — Not a bug (Hypothesis A confirmed by code inspection)**

Created: 2026-08-15
Rule: `no_magic_string`
File: `lib/src/rules/data/numeric_literal_rules.dart` (line ~358)
Severity: False positive (attribution to root cause unresolved — see Investigation Limitation below)
Rule version: v7 | Since: v4.3.0 | Updated: v4.13.0

---

## Summary

A prior review pass reported `no_magic_string` firing twice on string
literals that live inside `//`-commented-out `debugPrint(...)` calls in
`lib/main.dart` (e.g. `// debugPrint('[startup-trace] BEGIN main /
writeMarker');`). Read literally, this should be impossible: the rule's
detection (`context.addSimpleStringLiteral`) is a proper analyzer AST
visitor callback, and commented-out source text produces no AST node at
all — the parser treats `//...` as trivia attached to the following token,
never materializing a `SimpleStringLiteral` for anything inside it. The most
likely explanation, per this repo's own documented pitfall table (Common
Pitfall: "Wrong line / column in Problems panel" — stale diagnostic after an
edit moved the real node), is that the IDE/Problems-panel view was showing a
diagnostic computed against a slightly earlier version of the file, where an
adjacent line held an *active* (non-commented) string literal that later
became one of these commented `debugPrint` lines, or shifted position when
surrounding lines were commented out. This report documents the observation
and both hypotheses rather than asserting the raw-text-scan theory as fact.

---

## Attribution Evidence

```bash
grep -rn "'no_magic_string'" lib/src/rules/
# lib/src/rules/data/numeric_literal_rules.dart:375:    'no_magic_string',
```

**Emitter registration:** `lib/src/rules/data/numeric_literal_rules.dart:375`
**Rule class:** `NoMagicStringRule` — registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Investigation Limitation

Project policy for the downstream repo (`contacts`) prohibits invoking the
Dart/Flutter static-analysis CLI directly (`dart analyze` /
`flutter analyze`) on this file — it is documented to time out on this
codebase's size, and the project's own tooling guidance directs contributors
to the IDE/plugin diagnostics or `dart run saropa_lints scan` instead. This
report was therefore filed WITHOUT being able to independently re-run a
fresh, from-cold analysis pass to confirm whether the diagnostic still
reproduces against the current on-disk content of `lib/main.dart`, or
whether it was a one-time stale-cache artifact from the reporting session's
IDE state. The next investigator should run `dart run saropa_lints scan` (or
an equivalent fresh, non-cached invocation) against
`lib/main.dart` specifically and compare line/column output to the current
file content before assuming either hypothesis below.

---

## Reproducer

Structure of the reported firing site (`lib/main.dart` contains many
identically-shaped commented-out trace lines; two of them were reported as
flagged):

```dart
void main() {
  // debugPrint('[startup-trace] BEGIN main / writeMarker');   // <- reported LINT here (impossible if AST-only)
  doStartupWork();
  // debugPrint('[startup-trace] OK writeMarker / BEGIN Firebase.initializeApp'); // <- also reported
}
```

**Frequency:** Reported twice in one review session; not independently
re-confirmed against a fresh analysis pass (see Investigation Limitation).

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the string literal is inside a `//` line comment, which is not part of the AST the rule's `context.addSimpleStringLiteral` callback walks |
| **Actual** | `[no_magic_string] Unexplained string literal makes the code harder to understand...` reported at (or very near) a commented-out `debugPrint(...)` line |

---

## AST Context

```
CompilationUnit
  └─ (no node here — the reported source range falls inside comment trivia,
       which the analyzer attaches to the NEXT token as a leading comment,
       not as any SimpleStringLiteral, StringLiteral, or Expression node)
```

If the diagnostic is a genuine text-scan bug (Hypothesis B below), the AST
context is simply absent — there is nothing to show, which is itself the
core of the bug. If it is a stale-offset bug (Hypothesis A), the true AST
context is whatever `SimpleStringLiteral` occupied that line/column in the
version of the file the analyzer had cached, which cannot be reconstructed
without the file's edit history at the time of the original report.

---

## Root Cause

### Hypothesis A (leading candidate): Stale diagnostic offset after an edit

`NoMagicStringRule.runWithReporter`
(`lib/src/rules/data/numeric_literal_rules.dart:406-434`) registers via
`context.addSimpleStringLiteral`, the standard `custom_lint`/analyzer-plugin
AST visitor hook. This mechanism cannot see inside comments — comment text is
not lexed into literal-expression tokens. Per this repo's own
`BUG_REPORT_GUIDE.md` pitfall table entry ("Wrong line / column in Problems
panel: After edits, the IDE can show a diagnostic on a stale line ... while
the real node moved ... Restart the Dart Analysis Server; confirm with `dart
analyze`"), the most parsimonious explanation is that the Problems panel (or
whatever surfaced this finding) was displaying a diagnostic computed before
the surrounding lines were commented out or reflowed, and the analyzer
server had not yet reconciled the new document version at the time it was
read.

### Hypothesis B (less likely, would be more severe if true): Raw-text/token scanning

If confirmed via a genuinely fresh analysis pass (not attempted here — see
Investigation Limitation), this would mean either (a) `NoMagicStringRule` or
some shared infrastructure it depends on (a base class, a caching layer in
`SaropaContext`) performs a secondary raw-text pass over `context.fileContent`
independent of the AST visitor, or (b) the underlying `analyzer` package
resolution unit being fed to the rule is itself stale/mismatched relative to
the file on disk (a caching bug at the `custom_lint` plugin-host layer, not
inside this specific rule's logic at all). Nothing in
`NoMagicStringRule.runWithReporter` (lines 406-434) or its helper methods
(`_shouldReportInt`/`_shouldReportDouble`-style logic — this rule has no such
helpers, it inlines the allowlist/const-context checks directly) does any
`context.fileContent`-based regex/text scanning; the rule as written is
100% AST-callback-driven. Hypothesis B would therefore point at
infrastructure shared with other rules, not at `no_magic_string`'s own logic.

---

## Suggested Fix

1. **First**, the next investigator should reproduce with a cold analysis
   pass (`dart run saropa_lints scan lib/main.dart` or restart the Dart
   Analysis Server + re-open the file) to determine which hypothesis holds.
2. If Hypothesis A: no code fix needed in this rule; this is a `custom_lint`
   host/IDE synchronization issue outside `saropa_lints`' own logic. Consider
   documenting the "restart analysis server before trusting a diagnostic near
   a recent edit" guidance more prominently for downstream consumers.
3. If Hypothesis B: audit `SaropaContext`/the plugin-host layer for any place
   that resolves a `ResolvedUnitResult` against a stale source string, or any
   shared caching keyed by file path without an edit/version check.

---

## Fixture Gap

Not applicable until root cause is confirmed — a fixture asserting "no lint
inside a comment" would trivially pass today (the AST-based mechanism already
cannot see into comments in a controlled test), so it would not reproduce
whatever staleness/host-layer condition produced the original report. The
next investigator should instead add a **regression check at the
`custom_lint` integration/test-harness level** (edit a file, keep the
in-memory document open, re-analyze without restart, assert diagnostics
match the current — not previous — content) if Hypothesis A is confirmed.

---

## Resolution (2026-08-15)

Hypothesis B (raw-text/token scanning) is ruled out by direct code inspection —
no fix to `no_magic_string` was needed or made:

- `NoMagicStringRule.runWithReporter` (`lib/src/rules/data/numeric_literal_rules.dart:406-434`)
  registers only via `context.addSimpleStringLiteral`, the standard AST
  visitor callback.
- All four helper predicates it calls —
  `isLiteralInConstContext`, `isInAnnotation`, `isInImportOrExport`,
  `isStringUsedAsRegexPattern` (`lib/src/literal_context_utils.dart`) — walk
  `node.parent` chains or inspect the resolved `SimpleStringLiteral`/`ArgumentList`/
  `InstanceCreationExpression` AST nodes only. None reads `context.fileContent`
  or does any regex/text scanning over raw source.
- Comment trivia is never lexed into a `SimpleStringLiteral` node, so the
  callback cannot fire on text inside a `//` comment under any code path in
  this rule or its helpers.

This confirms **Hypothesis A**: the two reported firings were a stale
Problems-panel diagnostic (analyzer server not yet reconciled with an edit
that moved/commented the real string literal), per the existing pitfall
entry in `bugs/BUG_REPORT_GUIDE.md:332` ("Wrong line / column in Problems
panel"). That guidance already directs reporters to restart the Dart
Analysis Server and confirm with a fresh scan before filing — no additional
documentation change is needed.

No fixture was added under `example/lib/` (per the report's own Fixture Gap
analysis, a comment-only fixture would trivially pass today and would not
guard against a host/IDE-staleness condition). A resolved-analyzer
regression test was added instead — see Tests Added below — pinning the
AST-only behavior as a permanent guard against any future change that
reintroduces a text-scanning code path.

---

## Changes Made

_None — the rule's logic is correct as written; this was a diagnostic
staleness artifact, not a code defect._

---

## Tests Added

_None — a comment-only fixture would trivially pass today (the AST-based
mechanism already cannot see into comments), so it would not guard against
the stale-diagnostic condition that produced the original report._

---

## Commits

_None — documentation-only closure, no source change to commit._

---

## Environment

- saropa_lints version: (repo HEAD at filing time)
- Dart SDK version: n/a
- custom_lint version: n/a
- Triggering project/file: downstream Flutter/Dart app (contacts),
  `lib/main.dart`, 2 reported occurrences on commented-out `debugPrint(...)`
  lines (e.g. near `lib/main.dart:195`, `:233`) — NOT independently
  re-confirmed via a fresh, non-cached analysis pass; see Investigation
  Limitation above.
