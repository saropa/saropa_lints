# BUG: `require_yield_after_db_write` — fires on a one-shot atomic-save `writeAsString(flush: true)` with no loop, in a pure-Dart server package that has no UI thread and no `DelayUtils`/`yieldToUI()` to call

**Status: Open**

Created: 2026-09-18

Rule: `require_yield_after_db_write`
File: `lib/src/rules/resources/db_yield_rules.dart` (line ~369; shared logic at ~298-330, ~440-467)
Severity: False positive
Rule version: v1 | Since: v4.13.0

Rule source unchanged between v16.2.1 and 16.3.0 (HEAD); line numbers cite HEAD.

---

## Summary

`require_yield_after_db_write` reports on `await tmp.writeAsString(json, flush: true);` (`lib/src/server/snapshot_store.dart:85` in `saropa_drift_advisor`) — the middle step of an atomic temp-file-then-rename save (`SnapshotStore.save()`: create dir → write temp file → atomic rename), called once per manual snapshot action, not inside any loop and not on a per-request hot path. This is the sibling rule to `suggest_yield_after_db_read` (see the companion report `bugs/suggest_yield_after_db_read_false_positive_one_shot_file_io_non_flutter_server.md`, filed against the same source file, `db_yield_rules.dart`) and shares its exact two root causes:

1. **No loop-context check** — the rule fires identically whether the awaited write is inside a `for`/`while` loop or is a one-shot statement in a linear atomic-save sequence.
2. **No Flutter-context gate** — `saropa_drift_advisor` has no Flutter dependency at all (see its `pubspec.yaml`, `dependencies:` block is empty, "No runtime dependencies" documented at line 40-43); the rule's threat model ("blocking the UI thread," inserting `DelayUtils.yieldToUI()`) does not apply to this pure-`dart:io` debug HTTP server.

This rule is WARNING severity (vs. `suggest_yield_after_db_read`'s INFO), so the false-positive cost here is higher: it surfaces as a warning-level diagnostic on code with no actual UI to block.

---

## Attribution Evidence

```bash
cd /Users/craighathaway/Documents/src/saropa_lints && grep -rn "'require_yield_after_db_write'" lib/src/rules/
# lib/src/rules/resources/db_yield_rules.dart:369:    'require_yield_after_db_write',

grep -rn "'require_yield_after_db_write'" /Users/craighathaway/Documents/src/saropa_drift_advisor/lib/src/ /Users/craighathaway/Documents/src/saropa_drift_advisor/extension/src/
# (no output — 0 matches)
```

**Emitter registration:** `lib/src/rules/all_rules.dart:82` (`export 'resources/db_yield_rules.dart';`)
**Rule class:** `RequireYieldAfterDbWriteRule` — defined in `lib/src/rules/resources/db_yield_rules.dart:349`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

Reduced from `lib/src/server/snapshot_store.dart:67-92` in `saropa_drift_advisor` (no Flutter dependency; called once per manual snapshot action, in an atomic write-then-rename sequence):

```dart
import 'dart:convert';
import 'dart:io';

abstract final class SnapshotStore {
  static Future<void> save(String path, List<Object?> snapshots) async {
    final String json = jsonEncode(<String, dynamic>{'snapshots': snapshots});
    final File tmp = File('$path.tmp');
    await tmp.parent.create(recursive: true);
    // LINT (false positive) — single one-shot atomic-save write, no loop,
    // in a package with no Flutter dependency / UI thread at all.
    await tmp.writeAsString(json, flush: true);
    // Atomic rename immediately follows — not a ReturnStatement/throw/yieldToUI,
    // so _isFollowedBySafe() is false and the rule fires.
    await tmp.rename(path);
  }
}
```

**Frequency:** Always, for any `writeTxn`/`deleteAll`/`putAll`/`rawInsert`/`rawUpdate`/`rawDelete`/`writeAsString`/`writeAsBytes` call not immediately followed by a `yieldToUI()`/`return`/`throw` statement — regardless of loop context or whether the enclosing package depends on Flutter.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — one-shot atomic-save write, not inside a loop, in a package with no UI thread and no `DelayUtils` to yield to. |
| **Actual** | `[require_yield_after_db_write] Database or I/O write without a following yieldToUI() call may block the UI thread and cause visible frame drops. Write operations acquire exclusive locks that starve the framework of time to paint. {v1}` reported (WARNING) at `await tmp.writeAsString(json, flush: true);`. |

---

## AST Context

```
ClassDeclaration (SnapshotStore)
  └─ MethodDeclaration (save, static)
      └─ BlockFunctionBody
          └─ Block
              └─ TryStatement
                  └─ Block (try body)
                      ├─ [n]   VariableDeclarationStatement (final String json = jsonEncode(...);)
                      ├─ [n+1] VariableDeclarationStatement (final File tmp = File('$path.tmp');)
                      ├─ [n+2] ExpressionStatement (await tmp.parent.create(recursive: true);)
                      ├─ [n+3] ExpressionStatement (await tmp.writeAsString(json, flush: true);)  ← reporter.atNode(s) reports on this Statement
                      │        the AwaitExpression here is classified via _classifyDbAwait -> _DbOperationType.write (explicit method, db_yield_rules.dart:72-79)
                      └─ [n+4] ExpressionStatement (await tmp.rename(path);)  ← next statement; an awaited ExpressionStatement, not Return/Throw/yieldToUI, so _isFollowedBySafe([n+3]) == false
```

---

## Root Cause

Identical mechanism to the companion `suggest_yield_after_db_read` report — both rules share `_registerYieldCheck`, `_visitStatementsRecursive`, and `_isFollowedBySafe` (`db_yield_rules.dart:237-330`, `437-467`), differing only in `targetType` (`_DbOperationType.write` here vs. `.bulkRead`) and `LintImpact` (WARNING here vs. INFO).

**No loop-context check** — `_visitStatementsRecursive`'s `ForStatement`/`WhileStatement` branches (`db_yield_rules.dart:268-277`) recurse into loop bodies without ever recording "this statement is inside a loop," and `_isFollowedBySafe` (`db_yield_rules.dart:298-308`) decides purely from the next sibling statement in the immediately enclosing block. A one-shot `writeAsString` in an atomic-save sequence and a per-iteration write inside a loop are reported identically.

**No Flutter-context gate** — nothing in `RequireYieldAfterDbWriteRule.runWithReporter` (`db_yield_rules.dart:359-365`, which only checks `context.isInTestDirectory` before delegating to `_registerYieldCheck`) verifies the enclosing package depends on Flutter or that the call is reachable from a widget lifecycle method. `saropa_drift_advisor`'s `pubspec.yaml` `dependencies:` block (lines 32-43) is empty by design ("KEEP THIS LIST MINIMAL... this package ships inside consumer apps"), so there is no `flutter`/`package:flutter/scheduler.dart` dependency anywhere the rule could detect even if it tried — this file is provably server-side-only.

**Also note (does not excuse the finding, but relevant context):** the write here is deliberately mid-sequence in an atomic save (`writeAsString` → `rename`), documented at `snapshot_store.dart:64-66` ("Writes are atomic (temp file + rename) so a crash mid-write can never leave a half-written file"). Inserting a yield between the temp-file write and the rename would not violate correctness (the rename is still atomic), but it is functionally pointless here since there is no UI thread being protected.

---

## Suggested Fix

Same as the companion `suggest_yield_after_db_read` report:

1. Track loop-enclosure in `_visitStatementsRecursive` and use it to distinguish one-shot writes from per-iteration writes — at minimum to allow downgrading/suppressing the WARNING-severity finding for a provably one-shot call without requiring an `// ignore:`.
2. Gate `RequireYieldAfterDbWriteRule`/`SuggestYieldAfterDbReadRule` on the package actually depending on Flutter, since the correction message (`Insert await DelayUtils.yieldToUI();`) is not applicable — and the symbol not importable — in a Flutter-independent package.

---

## Fixture Gap

`example/lib/db_yield/require_yield_after_db_write_fixture.dart` (117 lines) contains **no actual test cases**, mirroring the read-side fixture — no `// expect_lint` annotations or executable examples were found via `grep -n "writeAsString\|expect_lint\|while\|for ("`. Missing:

1. **Case:** a `writeAsString()`/`writeTxn()`/`rawInsert()` call inside a `for`/`while` loop, not followed by a safe statement — expect **LINT**.
2. **Case:** a single one-shot `writeAsString()` call as the middle step of an atomic temp-file-then-rename save, not inside a loop — document current behavior (LINT) as a known limitation, or exclude once the loop-context fix lands.
3. **Case:** the same one-shot write inside a package with no Flutter dependency — once a Flutter-context gate exists, expect **NO lint**.

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
- Triggering project/file: `saropa_drift_advisor` 4.4.1 — `lib/src/server/snapshot_store.dart:85`. Scan report: `saropa_drift_advisor/reports/20260918/20260918_081229_findings.json`.

---

## Finish Report (2026-09-18)

**Status: Fixed.**

### Verdict

Confirmed false positive. The report's root-cause analysis (no Flutter-context
gate) was correct; the report's *other* suggested fix (loop-context tracking)
was reviewed and rejected as the primary mechanism — see "Fix chosen" below.

### Root cause

`RequireYieldAfterDbWriteRule.runWithReporter` (`lib/src/rules/resources/db_yield_rules.dart`)
never checked whether the enclosing package actually depends on Flutter,
even though the rule's entire premise — file header ("Rules for database and
heavy I/O yield patterns in **Flutter applications**"), the diagnostic text
("may block the UI thread"), and the correction message
(`await DelayUtils.yieldToUI();`, a Flutter-app symbol) — is Flutter-specific.
It fired identically in a pure-`dart:io` server package with no UI thread and
no way to import `DelayUtils`.

### Fix chosen (and why loop-context tracking was rejected)

Added a gate: `ProjectContext.getProjectInfo(context.filePath)?.isFlutterProject`
must be `true`, or the rule returns early — mirroring the same gate already
used by ~15 other rules in this codebase (`android_rules.dart`,
`debug_rules.dart`, `performance_rules.dart`, etc.) for the identical
"this concept doesn't apply outside Flutter" problem.

The report's *other* suggested fix — tracking loop-enclosure in
`_visitStatementsRecursive` and only firing on writes inside a loop — was
considered and rejected: the rule's own documented **BAD** example
(`await isar.writeTxn(...); processData();`) is itself a one-shot,
non-loop write, and is the canonical case the rule exists to catch. Gating
on loop-context alone would silence that documented true positive as a
side effect, which is a regression, not a fix. The real distinguishing
factor between the doc's BAD example and this bug report is "is there a
UI thread to protect at all" (Flutter vs. not) — not "is this in a loop".
The Flutter-context gate targets that distinction precisely without
touching loop semantics.

This intentionally also silences the *sibling* loop-based finding the
companion report explicitly declined to include (`generation_handler.dart:695`,
inside a `while(true)` in the same non-Flutter package) — consistent with
the rule's documented Flutter-only scope, and not a separate concession.

### Files changed

- `lib/src/rules/resources/db_yield_rules.dart` — added the
  `isFlutterProject` gate to `RequireYieldAfterDbWriteRule.runWithReporter`
  (and to `SuggestYieldAfterDbReadRule`, see companion report), plus doc
  comment updates noting the new suppression.
- `example/lib/db_yield/require_yield_after_db_write_fixture.dart` — updated
  the stub's NOTE comment to document the new suppression condition and
  point at the resolved-harness regression tests (this example package is
  itself non-Flutter, so no fixture code here can demonstrate the rule
  firing).
- `test/rules/resources/db_yield_rules_test.dart` — added a
  `Database Yield Rules - Flutter-context gate` group:
  - Reproduces the exact bug-report snippet (`SnapshotStore.save`-shaped
    atomic write) via the existing `resolved_rule_harness.dart` oracle
    (which resolves fixtures inside this repo's non-Flutter `example`
    package) and asserts **no** `require_yield_after_db_write` diagnostic.
  - Adds a small local harness (`_runRuleResolvedInProject`) that
    fabricates a synthetic project with a `flutter:`-declaring
    `pubspec.yaml` (no real Flutter SDK required, since the fixture code
    only uses `dart:io`) and asserts the **same** write snippet still
    fires there — proving the fix does not regress the true positive.

### Tests

`dart test test/rules/resources/db_yield_rules_test.dart` — 12/12 passed,
including the 2 new tests for this rule (the other 2 new tests cover the
companion `suggest_yield_after_db_read` rule).

`dart analyze lib/src/rules/resources/db_yield_rules.dart
test/rules/resources/db_yield_rules_test.dart` — no issues found.

### Proposed CHANGELOG line

- fix: `require_yield_after_db_write` no longer fires in packages that do
  not depend on Flutter — its entire "blocks the UI thread" premise does
  not apply there, and `DelayUtils.yieldToUI()` is not importable.
