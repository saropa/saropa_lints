# BUG: `move_variable_closer_to_its_usage` — suggests relocating a throwing `await` past HTTP header/status writes a `catch` block depends on, causing a real bug when applied

**Status: Open**

Created: 2026-09-18

Rule: `move_variable_closer_to_its_usage`
File: `lib/src/rules/code_quality/code_quality_variables_rules.dart` (line ~2441, class `MoveVariableCloserToUsageRule` at line 2421)
Severity: False positive — High. This is not cosmetic: following the rule's suggestion **introduced a real bug** (a 500 JSON error response was served with a `Content-Disposition: attachment` header advertising a `.sqlite` file), so per the severity guide ("forces `// ignore:` workaround on a common pattern") this undersells it — obeying the fix actively broke correct code.
Rule version: v9 | Since: v0.1.4 | Updated: v14.5.10

Rule source unchanged between v16.2.1 and 16.3.0 (HEAD); line numbers cite HEAD (checkout at `9456b83e`, `v16.2.1-13-g9456b83e`).

---

## Summary

`move_variable_closer_to_its_usage` flagged `final bytes = await getBytes();` in `saropa_drift_advisor/lib/src/server/schema_handler.dart`'s `sendDatabaseFile` because it is declared several statements before its only read (`res.add(bytes)`). A fix agent complied and moved the declaration down, past three statements that set `res.statusCode = 200`, the octet-stream content type, and the `Content-Disposition: attachment` header. Because `getBytes()` is an `await`ed host callback that can throw, moving its evaluation past those writes means a throw now happens **after** the response already looks like a successful attachment download; the `catch` block sets status 500 and switches to JSON content-type but never clears `Content-Disposition`, so a client following that header (`curl -OJ`, an `<a>` download link) saves the JSON error body to disk as if it were the requested `.sqlite` file. The rule's dataflow model has no concept of "this declaration's own evaluation can throw" or "an intervening statement has an externally-visible side effect that a sibling `catch`/`finally` depends on" — it is purely a statement-count / direct-child-of-block positional check.

---

## Attribution Evidence

```bash
$ grep -rn "'move_variable_closer_to_its_usage'" lib/src/rules/
lib/src/rules/code_quality/code_quality_variables_rules.dart:2441:    'move_variable_closer_to_its_usage',

$ grep -rn "'move_variable_closer_to_its_usage'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# 0 matches
```

**Emitter registration:** `lib/saropa_lints.dart:715` — `MoveVariableCloserToUsageRule.new,`
**Rule class:** `MoveVariableCloserToUsageRule` — defined `lib/src/rules/code_quality/code_quality_variables_rules.dart:2421` (note: the registered `LintCode` id is `move_variable_closer_to_its_usage`, but the Dart class and doc-comment alias both drop "its" — `move_variable_closer_to_usage`; same rule, just a naming mismatch between the class and the emitted code string)
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

Current code (`saropa_drift_advisor/lib/src/server/schema_handler.dart:616-646`, `SchemaHandler.sendDatabaseFile`; verified identical statement order at `git show HEAD:lib/src/server/schema_handler.dart:614-644` — the guarding comment was added after the bug was caught, but the underlying await-before-headers ordering is original, not a recent change):

```dart
Future<void> sendDatabaseFile(HttpResponse res, Future<List<int>> Function() getBytes) async {
  try {
    // LINT (false positive): rule suggests moving this declaration down to
    // just before `res.add(bytes)`, i.e. AFTER the header/status writes below.
    final bytes = await getBytes(); // getBytes() is host-supplied and can throw

    res.statusCode = HttpStatus.ok;
    res.headers.contentType = ContentType('application', 'octet-stream');
    res.headers.set('Content-Disposition', 'attachment; filename="db.sqlite"');
    res.add(bytes);
  } on Object catch (error, stack) {
    // If `bytes` were declared here instead (per the rule's suggestion),
    // a throw from getBytes() would happen AFTER the three lines above ran,
    // so this catch's response would carry a stale success status and an
    // attachment Content-Disposition header on a JSON error body.
    res.statusCode = HttpStatus.internalServerError;
    res.headers.contentType = ContentType.json;
    res.write(jsonEncode({'error': error.toString()}));
  } finally {
    await res.close();
  }
}
```

**Frequency:** Always, for this shape: a throwing `await` declared before statements that mutate object state (headers/status) which a sibling `catch`/`finally` also mutates.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the declaration's position is load-bearing: it must run, and be allowed to throw, before the success-path header/status writes |
| **Actual** | `[move_variable_closer_to_its_usage] Variable declared far from its first use...` reported on `final bytes = await getBytes();`, and the auto-fix (`MoveDeclarationCloserFix`) relocates it past the header writes, changing which statements execute before a possible throw |

---

## AST Context

```
MethodDeclaration (sendDatabaseFile)
  └─ BlockFunctionBody
      └─ TryStatement
          ├─ Block (try body)
          │   ├─ VariableDeclarationStatement (final bytes = await getBytes();)  ← flagged declaration
          │   ├─ ExpressionStatement (res.statusCode = HttpStatus.ok;)
          │   ├─ ExpressionStatement (res.headers.contentType = ...;)
          │   ├─ ExpressionStatement (res.headers.set(...);)
          │   └─ ExpressionStatement (res.add(bytes);)               ← first (only) use
          ├─ CatchClause
          │   └─ Block (sets statusCode = 500, contentType = json, writes JSON body)
          └─ Block (finally: await res.close();)
```

---

## Root Cause

`runWithReporter` (`code_quality_variables_rules.dart:2456-2524`) registers on `Block` and, for each locally-declared variable, calls `_canMoveCloser` (`code_quality_variables_rules.dart:2546-2609`) to decide whether to flag it. `_canMoveCloser`'s entire model is:

1. the first use must be a direct-child statement of the same block (`code_quality_variables_rules.dart:2556-2557`), and
2. at least `_minInterveningStatements` (= 3, `code_quality_variables_rules.dart:2454`) sibling statements between the declaration and the use are not themselves part of the same "declaration batch" (`code_quality_variables_rules.dart:2581-2607`).

Nowhere in `_canMoveCloser`, nor in the rest of the class, is there any check on:
- whether `decl.initializer` (here, `await getBytes()`) can throw — there is no inspection of `AwaitExpression`, no call-graph/throws analysis at all, and
- whether any of the intervening statements have an externally-visible side effect (a field/property write on an object — here `res.headers`/`res.statusCode` — that is also touched by an enclosing `catch`/`finally`).

This is confirmed by a direct search: `TryStatement`, `CatchClause`, `AwaitExpression`, and `await` do not appear anywhere in the rule's analysis code (`code_quality_variables_rules.dart:2421-2635`) — the only occurrences of "await" in that whole region are inside doc-comment examples (lines 2410-2412), never in a live AST check. The rule is purely positional/statement-counting; it has no notion of control-flow-sensitive safety for relocating an expression that can fail partway through a `try` block.

---

## Suggested Fix

In `_canMoveCloser` (`code_quality_variables_rules.dart:2546`), before returning `true`:
- inspect `decl.initializer` for an `AwaitExpression` or a call to a function/method not provably non-throwing, and
- inspect whether `decl` sits inside a `TryStatement` that has a `CatchClause` or `finally` block, and whether any statement between the declaration and the proposed new position has an externally-visible side effect (assignment to a property/field of an object reachable from that `catch`/`finally`, e.g. `HttpResponse.headers`/`.statusCode`, a file write, or a mutation of shared/global state).

If both hold, suppress the suggestion — or at minimum downgrade it to informational with an explicit note about reordering risk, rather than presenting a `MoveDeclarationCloserFix` (`code_quality_variables_rules.dart:2632-2634`) as a safe mechanical refactor.

---

## Fixture Gap

The fixture at `example/lib/code_quality/move_variable_closer_to_its_usage_fixture.dart` has no case involving `try`/`catch`/`await` at all (confirmed: no `try`, `catch`, or `await` keyword appears anywhere in that fixture file). It should add:

1. **Throwing `await` before side-effecting statements read by a sibling `catch`** — expect NO LINT:
   ```dart
   Future<void> sendFile(HttpResponse res, Future<List<int>> Function() getBytes) async {
     try {
       final bytes = await getBytes(); // NO LINT: throwing, and catch below depends on header order
       res.statusCode = 200;
       res.headers.set('Content-Disposition', 'attachment');
       res.add(bytes);
     } catch (e) {
       res.statusCode = 500;
     }
   }
   ```
2. A contrasting **non-throwing, side-effect-free declaration with the same distance** — expect LINT (to confirm the fix doesn't over-suppress once the throw/side-effect guard is added).

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

- saropa_lints version: 16.2.1 resolved (checkout under investigation: `9456b83e`, `v16.2.1-13-g9456b83e`; rule source unchanged since v16.2.1)
- Dart SDK version: 3.12.2 (stable)
- custom_lint version: n/a — findings from `saropa_lints scan` CLI / VS Code extension
- Triggering project/file: `saropa_drift_advisor` 4.4.1 — `lib/src/server/schema_handler.dart:616-646` (`SchemaHandler.sendDatabaseFile`). Scan report: `saropa_drift_advisor/reports/20260918/20260918_081229_findings.json`

---

## Finish Report (2026-09-18)

**Verdict: Valid.** The report's root-cause analysis was accurate: `_canMoveCloser` in `MoveVariableCloserToUsageRule` (`lib/src/rules/code_quality/code_quality_variables_rules.dart`) is a purely positional/statement-count check with no awareness that a declaration's own initializer can throw, or that intervening statements can have externally-visible side effects a sibling `catch`/`finally` depends on seeing (or not seeing) before that throw.

### Root cause

`_canMoveCloser` only checked (1) that the first use is a direct-child statement of the same block, and (2) that at least `_minInterveningStatements` (3) unrelated sibling statements separate the declaration from its use. It never inspected `decl.initializer` for an `await`, nor whether the declaration sits in a `try` block whose `catch`/`finally` could observe side effects from statements between the declaration and the proposed new position.

### Fix

Added a narrow, structural (not name/string-based) guard in `_canMoveCloser`, evaluated before the existing distance check: if the declaration's initializer contains a top-level `await` expression (an `_AwaitFinder` `RecursiveAstVisitor` that does not descend into nested `FunctionExpression`s, since an `await` inside a closure runs on the closure's own schedule) **and** the declaration statement is a direct child of the `try` block of a `TryStatement` that has at least one `catch` clause or a `finally` block, the rule now declines to flag it (`_isDirectTryBodyWithHandler`). This is a semantic/structural check on the resolved AST (initializer shape + enclosing `TryStatement`/`CatchClause`/`finallyBlock`), not a heuristic on names or strings, and it does not touch the unrelated batch-declaration / loop-accumulator / branch-fan-out guards already in the rule.

The guard is intentionally narrow: it does not attempt general throws-analysis on arbitrary calls (out of scope, and the report's own suggested fix flagged this as a "minimum" bar) — only `await`, which is exactly the shape in the reproducer and is a syntactically checkable proxy for "can suspend and may complete with an error that skips the remaining statements in this block."

### Files changed

- `lib/src/rules/code_quality/code_quality_variables_rules.dart` — added the `_containsAwait` / `_isDirectTryBodyWithHandler` guard and `_AwaitFinder` visitor in `MoveVariableCloserToUsageRule`.
- `example/lib/code_quality/move_variable_closer_to_its_usage_fixture.dart` — added Defect 5 (NO LINT: throwing await before header/status writes inside `try`/`catch`, mirroring the reproducer) and a contrasting LINT case (`_syncInitializerInTryStillFlagged`) proving the new guard doesn't blanket-suppress declarations inside `try` blocks that don't await.
- `test/rules/code_quality/move_variable_closer_to_its_usage_fp_test.dart` (new) — resolved-analyzer regression tests: NO LINT for throwing-await-before-catch and throwing-await-before-finally-only; LINT for a same-shape non-throwing initializer and for a throwing await with no enclosing `try` at all (proving the guard is scoped to the `try`+await combination, not a blanket await suppression).

### Tests

- `dart analyze lib/src/rules/code_quality/code_quality_variables_rules.dart test/rules/code_quality/move_variable_closer_to_its_usage_fp_test.dart` — No issues found.
- `dart analyze example/lib/code_quality/move_variable_closer_to_its_usage_fixture.dart` — No issues found.
- `dart test test/rules/code_quality/move_variable_closer_to_its_usage_fp_test.dart` — All 4 tests passed (2 NO-LINT regression cases for the report's exact shape plus a finally-only variant, 2 LINT contrast cases proving no over-suppression).
- `dart format` run on all three touched files — no changes needed beyond what was already written in the desired style.

### Known remaining gap (from review)

An Opus review (ship-with-nits) confirmed the fix correctly clears the reported shape but flagged that the guard's scope is narrower than the underlying hazard: it keys specifically on `await` as the "can suspend/throw mid-block" signal, not on general throw-safety. A **synchronous** throwing initializer with the same shape — e.g. `try { final a = int.parse(s); sideEffect(); ...; use(a); } catch (_) {}` — has the identical reordering hazard (moving `a`'s declaration later lets `sideEffect()` run before a throw that used to happen first) but is **not** exempted by this fix and is still flagged. This is a deliberate scope decision, not an oversight: general throws-analysis on arbitrary synchronous calls is open-ended (any method can throw) and was out of scope for this narrow fix, matching the original bug report's own reproducer (which was specifically an `await`).

The review also caught that the fixture's `_syncInitializerInTryStillFlagged` case and its accompanying test had a misleading comment implying `_compute(seed)` "can't throw" — that was not the actual reason it's still flagged (it's flagged simply because it has no `await`, regardless of whether it can throw). Both the fixture comment (`example/lib/code_quality/move_variable_closer_to_its_usage_fixture.dart`) and the test title/header comment (`test/rules/code_quality/move_variable_closer_to_its_usage_fp_test.dart`) were corrected to state the actual, narrower scope honestly and to call out the synchronous-throwing-initializer case as a known, separate, not-yet-fixed false-positive shape.

A follow-up bug report for the synchronous case may be worth filing separately if this class of pattern recurs in practice; not filed here since it is a scope note on this fix's documentation rather than a newly observed FP.
