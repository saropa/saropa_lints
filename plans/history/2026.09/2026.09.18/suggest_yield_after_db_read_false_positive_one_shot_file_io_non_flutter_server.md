# BUG: `suggest_yield_after_db_read` — fires on a one-shot `readAsString()` with no loop, in a pure-Dart server package that has no UI thread and no `DelayUtils`/`yieldToUI()` to call

**Status: Open**

Created: 2026-09-18

Rule: `suggest_yield_after_db_read`
File: `lib/src/rules/resources/db_yield_rules.dart` (line ~430; shared logic at ~298-330, ~440-467)
Severity: False positive
Rule version: v1 | Since: v4.13.0

Rule source unchanged between v16.2.1 and 16.3.0 (HEAD); line numbers cite HEAD.

---

## Summary

`suggest_yield_after_db_read` reports on `final String raw = await file.readAsString();` (`lib/src/server/snapshot_store.dart:44` in `saropa_drift_advisor`) — a single, one-shot on-disk JSON read inside `SnapshotStore.load()`, called once when the debug server starts, not inside any loop and not on a per-request hot path. Two things combine to make this a false positive:

1. The rule treats every `readAsString`/`writeAsString`/etc. as a "database or heavy I/O" operation (this is intentional per the rule's own doc header — see Root Cause) but has **no loop-context awareness at all**: whether the awaited call sits inside a `for`/`while` loop or is a single top-level statement makes no difference to whether it fires. A second claimed finding in this same scan, at `lib/src/server/generation_handler.dart:695` inside a genuine `while (true)` ancestor-directory walk, was examined and is **not** included in this report — it mechanically satisfies every condition the rule checks (bulk-read method, inside a loop, not immediately followed by a safe statement) and is a legitimate, if low-severity, match, not a false positive of the rule as documented. The `snapshot_store.dart:44` site has no such loop, so the same "the pattern genuinely matches, just at low real-world severity" defense that applies to the `while(true)` site does not apply here — this one is unconditionally a single call with no repetition of any kind.
2. `saropa_drift_advisor` is a pure-Dart package with **no Flutter dependency at all** (its `pubspec.yaml` `dependencies:` block, line 32-43, is empty and explicitly documents "No runtime dependencies" — it is a standalone `dart:io` debug HTTP server, not a Flutter app). The rule's entire threat model — "Flutter runs UI and Dart code on the same thread... blocking frame rendering... yieldToUI() gives the framework a chance to process pending frames" (file header, `db_yield_rules.dart:1-24`) — does not apply here: there is no UI thread to block, and the rule's own quick-fix/correction message (`Consider inserting await DelayUtils.yieldToUI();`) names a symbol (`DelayUtils.yieldToUI()`) that is not importable in this package at all.

---

## Attribution Evidence

```bash
cd /Users/craighathaway/Documents/src/saropa_lints && grep -rn "'suggest_yield_after_db_read'" lib/src/rules/
# lib/src/rules/resources/db_yield_rules.dart:430:    'suggest_yield_after_db_read',

grep -rn "'suggest_yield_after_db_read'" /Users/craighathaway/Documents/src/saropa_drift_advisor/lib/src/ /Users/craighathaway/Documents/src/saropa_drift_advisor/extension/src/
# (no output — 0 matches)
```

**Emitter registration:** `lib/src/rules/all_rules.dart:82` (`export 'resources/db_yield_rules.dart';`)
**Rule class:** `SuggestYieldAfterDbReadRule` — defined in `lib/src/rules/resources/db_yield_rules.dart:401`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

Reduced from `lib/src/server/snapshot_store.dart:34-62` in `saropa_drift_advisor` (no Flutter dependency; called once at server startup):

```dart
import 'dart:convert';
import 'dart:io';

abstract final class SnapshotStore {
  static Future<List<Object?>> load(String path) async {
    final File file = File(path);
    if (!await file.exists()) return <Object?>[];
    // LINT (false positive) — single one-shot read at process startup, no
    // loop, and this package has no Flutter dependency / UI thread at all.
    final String raw = await file.readAsString();
    if (raw.trim().isEmpty) return <Object?>[];
    return (jsonDecode(raw) as List<Object?>);
  }
}
```

**Frequency:** Always, for any `readAsString`/`readAsBytes`/`readAsLines`/`findAll`/`rawQuery`/`loadJsonFromAsset` call not immediately followed by a `yieldToUI()`/`return`/`throw` statement — regardless of loop context or whether the enclosing package depends on Flutter.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — one-shot startup read, not inside a loop, in a package with no UI thread and no `DelayUtils` to yield to. |
| **Actual** | `[suggest_yield_after_db_read] Bulk database or I/O read without a following yieldToUI() call. Deserializing large payloads on the main isolate can cause frame drops during data-heavy workflows. {v1}` reported at `final String raw = await file.readAsString();`. |

---

## AST Context

```
ClassDeclaration (SnapshotStore)
  └─ MethodDeclaration (load, static)
      └─ BlockFunctionBody
          └─ Block
              ├─ [0] VariableDeclarationStatement (final File file = File(path);)
              ├─ [1] IfStatement (if (!await file.exists()) return ...;)
              ├─ [2] VariableDeclarationStatement (final String raw = await file.readAsString();)  ← reporter.atNode(s) reports on this whole Statement
              │     the AwaitExpression here is classified via _classifyDbAwait -> _DbOperationType.bulkRead
              └─ [3] IfStatement (if (raw.trim().isEmpty) return ...;)  ← next statement; not itself a ReturnStatement, so _isFollowedBySafe([2]) == false
```

(Statements [0]-[3] sit inside a `TryStatement` body — `_visitStatementsRecursive` flattens into the try-block's own statement list, `db_yield_rules.dart:251-260`.)

---

## Root Cause

**No loop-context check.** `_visitStatementsRecursive` (`db_yield_rules.dart:237-280`) recurses into `TryStatement`/`IfStatement`/`ForStatement`/`WhileStatement` bodies to find candidate statements, but never sets or checks any "am I inside a loop" flag:

```dart
if (s is ForStatement) {
  final body = s.body;
  if (body is Block) _visitStatementsRecursive(body, onStatement);
  continue;
}
if (s is WhileStatement) {
  final body = s.body;
  if (body is Block) _visitStatementsRecursive(body, onStatement);
  continue;
}
```

and the reporting decision, `_isFollowedBySafe` (`db_yield_rules.dart:298-308`), looks only at the **next sibling statement in the immediately enclosing block** — never at whether that block is itself a loop body or a one-shot top-level sequence:

```dart
bool _isFollowedBySafe(List<Statement> stmts, int i) {
  if (i >= stmts.length - 1) return true;
  final Statement next = stmts[i + 1];
  if (_isYieldToUI(next)) return true;
  if (next is ReturnStatement) return true;
  if (next is ExpressionStatement && next.expression is ThrowExpression) return true;
  return false;
}
```

A one-shot read at `snapshot_store.dart:44` and a per-iteration read inside a `while (true)` loop (the rejected `generation_handler.dart:695` claim) are therefore reported identically — the rule cannot distinguish "runs once at startup" from "runs on every loop iteration," which is exactly the axis the file's own doc header (`db_yield_rules.dart:1-24`) frames its concern around ("heavy I/O can block frame rendering... during data-heavy workflows").

**File I/O classified as DB/IO — by design, not a bug.** `_bulkReadMethods` (`db_yield_rules.dart:79-86`) explicitly lists `readAsString`, `readAsBytes`, `readAsLines`, `loadJsonFromAsset` under a "File / asset I/O" comment, and the file header says "database **and heavy I/O**" — so file I/O being in scope is intentional, not itself a defect. What the rule cannot know is whether the *file* being read is small/one-shot (a config or snapshot file at startup) versus large/repeated (a hot-path asset load).

**No Flutter-context gate at all.** Nothing in `RequireYieldAfterDbWriteRule`/`SuggestYieldAfterDbReadRule`/`_registerYieldCheck` (`db_yield_rules.dart:314-467`) checks whether the enclosing package/file has any Flutter dependency, imports `dart:ui`/`package:flutter/scheduler.dart`, or is reachable from a widget build/state method. It fires uniformly in pure-`dart:io` server code with the same message and the same `DelayUtils.yieldToUI()` correction text as it would in a Flutter widget's `initState`.

---

## Suggested Fix

1. Track loop-enclosure in `_visitStatementsRecursive` (pass a `bool insideLoop` parameter, set `true` when recursing into a `ForStatement`/`WhileStatement` body) and either skip reporting for `SuggestYieldAfterDbReadRule` (INFO) when `!insideLoop` and the enclosing function is not itself reachable from a widget lifecycle method, or at minimum expose the distinction so downgrading/suppression is possible without an `// ignore:`.
2. Gate the whole `db_yield_rules.dart` pair (or at least this INFO-level one) on the package actually depending on Flutter — e.g. via `context`'s equivalent of a `pubspec.yaml` Flutter-SDK check (if the rule framework exposes one), or on the enclosing file importing something Flutter-shaped — since the entire premise ("blocking frame rendering," "the main isolate") does not hold in a plain `dart:io` server/CLI package.

---

## Fixture Gap

`example/lib/db_yield/suggest_yield_after_db_read_fixture.dart` (113 lines) contains **no actual test cases** — it is a stub with only a top-level comment (`// NOTE: suggest_yield_after_db_read fires on bulk database reads (findAll, getAll) without yield.`) and an empty `_note304()` function; there is not a single `// expect_lint` annotation or executable example in the file. Missing:

1. **Case:** a `readAsString()`/`readAsBytes()` call inside a `for`/`while` loop, not followed by a safe statement — expect **LINT**.
2. **Case:** a single one-shot `readAsString()` call at the top level of a function (no loop), not followed by a safe statement — document the rule's current behavior (LINT, per today's implementation) as a known limitation, or exclude it once the loop-context fix above lands.
3. **Case:** the same one-shot read inside a package with no Flutter dependency — once a Flutter-context gate exists, expect **NO lint**; until then, this is the regression case for that fix.

---

## Changes Made

_Not yet — open report._

---

## Tests Added

_Not yet — open report._

---

## Commits

_Not yet — open report._

---

## Environment

- saropa_lints version: 16.2.1 (findings produced), 16.3.0 / HEAD (source reviewed; unchanged for this file between the two)
- Dart SDK version: 3.12.2 (stable)
- custom_lint version: n/a (scan via `saropa_lints scan` / VS Code extension)
- Triggering project/file: `saropa_drift_advisor` 4.4.1 — `lib/src/server/snapshot_store.dart:44`. Scan report: `saropa_drift_advisor/reports/20260918/20260918_081229_findings.json`.

---

## Finish Report (2026-09-18)

**Status: Fixed.**

### Verdict

Confirmed false positive, fixed consistently with the companion
`require_yield_after_db_write` report (same file, same shared logic).

### Root cause

`SuggestYieldAfterDbReadRule.runWithReporter` (`lib/src/rules/resources/db_yield_rules.dart`)
had no Flutter-context gate at all, so it fired uniformly in Flutter apps
and in pure-`dart:io` server/CLI packages, even though the rule's entire
justification (file header, "Deserializing large payloads on the main
isolate can cause frame drops", the `DelayUtils.yieldToUI()` correction
message) only makes sense where a UI thread exists to protect.

The report's own analysis of the sibling `generation_handler.dart:695`
finding (a genuine `while (true)` loop read in the same non-Flutter
package) was reviewed for consistency: that finding mechanically matches
the *current* implementation's criteria, but it does not survive the
Flutter-context gate either — which is intentional and consistent with the
rule's documented scope, not an oversight. See the companion report's
Finish Report for why loop-context tracking (the report's other suggested
fix) was rejected as the primary mechanism: it would have silenced the
rule's own documented one-shot **BAD** example
(`final all = await isar.contacts.findAll(); processData(all);`), which is
not itself inside a loop.

### Fix

Added the same gate as the companion rule:
`ProjectContext.getProjectInfo(context.filePath)?.isFlutterProject` must be
`true`, or the rule returns early before registering its visitor — matching
the established pattern used by ~15 other rules in this codebase.

### Files changed

- `lib/src/rules/resources/db_yield_rules.dart` — added the
  `isFlutterProject` gate to `SuggestYieldAfterDbReadRule.runWithReporter`
  (and to `RequireYieldAfterDbWriteRule`, see companion report), plus doc
  comment updates noting the new suppression.
- `example/lib/db_yield/suggest_yield_after_db_read_fixture.dart` — updated
  the stub's NOTE comment to document the new suppression condition and
  point at the resolved-harness regression tests.
- `test/rules/resources/db_yield_rules_test.dart` — added coverage in the
  new `Database Yield Rules - Flutter-context gate` group:
  - Reproduces the exact bug-report snippet (`SnapshotStore.load`-shaped
    one-shot startup read) via the existing `resolved_rule_harness.dart`
    oracle (resolves inside this repo's non-Flutter `example` package) and
    asserts **no** `suggest_yield_after_db_read` diagnostic.
  - Uses a local harness (`_runRuleResolvedInProject`) that fabricates a
    synthetic project with a `flutter:`-declaring `pubspec.yaml` and
    asserts the same read snippet still fires there, proving the true
    positive is preserved.

### Tests

`dart test test/rules/resources/db_yield_rules_test.dart` — 12/12 passed,
including the 2 new tests for this rule (the other 2 cover the companion
`require_yield_after_db_write` rule).

`dart analyze lib/src/rules/resources/db_yield_rules.dart
test/rules/resources/db_yield_rules_test.dart` — no issues found.

### Proposed CHANGELOG line

- fix: `suggest_yield_after_db_read` no longer fires in packages that do
  not depend on Flutter — its entire "blocks the main isolate during
  deserialization" premise does not apply there, and
  `DelayUtils.yieldToUI()` is not importable.
