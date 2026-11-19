# BUG: `avoid_throw_in_catch_block` — Flags `throw Error.throwWithStackTrace(...)`, the Stack-Preserving Pattern It Recommends

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-09-18
Rule: `avoid_throw_in_catch_block`
File: `lib/src/rules/flow/exception_rules.dart` (line ~172)
Severity: False positive
Rule version: v6 | Since: v0.1.4 | Updated: v4.13.0

---

## Summary

`avoid_throw_in_catch_block` reports on `throw Error.throwWithStackTrace(newError, caughtStackTrace);` inside a `catch` block. `Error.throwWithStackTrace` is the `dart:core` API whose entire purpose is to throw a new error while explicitly preserving an existing `StackTrace` — exactly the pattern the rule's own `correctionMessage` recommends (*"Use rethrow ... or Error.throwWithStackTrace to preserve the stack trace"*). The rule's detector matches on the bare presence of a `ThrowExpression` node inside a catch block and does not special-case its own recommended call.

---

## Attribution Evidence

```bash
$ cd /Users/craighathaway/Documents/src/saropa_lints && grep -rn "'avoid_throw_in_catch_block'" lib/src/rules/
lib/src/rules/flow/exception_rules.dart:192:    'avoid_throw_in_catch_block',

$ grep -rn "'avoid_throw_in_catch_block'" /Users/craighathaway/Documents/src/saropa_drift_advisor/lib/src/ /Users/craighathaway/Documents/src/saropa_drift_advisor/extension/src/
# (no output — 0 matches)
```

Rule source unchanged between v16.2.1 and 16.3.0 (HEAD); line numbers below cite HEAD.

**Emitter registration:** `lib/src/rules/flow/exception_rules.dart:192` (`LintCode`)
**Rule class:** `AvoidThrowInCatchBlockRule` — defined at `lib/src/rules/flow/exception_rules.dart:172`. Exported via barrel `lib/src/rules/all_rules.dart:64` (`export 'flow/exception_rules.dart';`). Registered as a runnable rule via factory at `lib/saropa_lints.dart:333` (`AvoidThrowInCatchBlockRule.new,`).
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

```dart
Future<void> writeAll(List<String> stmts) async {
  for (final s in stmts) {
    try {
      await writeQuery(s);
    } on Object catch (statementError, statementStack) {
      // Preserves the ORIGINAL stack trace via the second positional arg —
      // this is dart:core's documented mechanism for exactly that purpose.
      throw Error.throwWithStackTrace(
        StateError('write failed: $statementError'),
        statementStack, // <-- the caught trace, explicitly forwarded
      );
      // LINT (false positive) — rule flags the `throw` token above
    }
  }
}
```

Real-world site: `saropa_drift_advisor/lib/src/server/edits_batch_handler.dart:76-88`.

**Frequency:** Always, for any `throw Error.throwWithStackTrace(...)` inside a `catch` block, regardless of whether the second argument is (or derives from) the caught `StackTrace`.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — `throw Error.throwWithStackTrace(newError, originalStackTrace)` already preserves the original trace; it is the rule's own suggested fix. |
| **Actual** | `[avoid_throw_in_catch_block] Throwing a new error in a catch block without preserving the original stack trace makes debugging much harder. ...` fires at `edits_batch_handler.dart:80`. |

---

## AST Context

```
CompilationUnit (edits_batch_handler.dart)
  └─ TryStatement
      └─ CatchClause (on Object catch (statementError, statementStack))
          └─ Block
              └─ ThrowStatement  ← ThrowExpression visited by _ThrowVisitor
                  └─ ThrowExpression
                      └─ MethodInvocation (Error.throwWithStackTrace(newError, statementStack))
                          ← reporter.atNode(node) reports on the ThrowExpression itself
```

Note: a bare `rethrow;` in the same position would produce a `RethrowExpression` node, a different AST type from `ThrowExpression` — the visitor below only overrides `visitThrowExpression`, so `rethrow` is structurally exempt already (not by any explicit check, but because the visitor never visits that node type for it).

---

## Root Cause

`AvoidThrowInCatchBlockRule.runWithReporter` (`exception_rules.dart:205-212`) registers `context.addCatchClause` and, for every catch clause, runs `node.body.visitChildren(_ThrowVisitor(reporter, code))`. `_ThrowVisitor` (`exception_rules.dart:220-231`):

```dart
class _ThrowVisitor extends RecursiveAstVisitor<void> {
  ...
  @override
  void visitThrowExpression(ThrowExpression node) {
    reporter.atNode(node);          // <-- unconditional report
    super.visitThrowExpression(node);
  }
}
```

`visitThrowExpression` reports on **every** `ThrowExpression` found inside the catch body, with no inspection of what is being thrown. There is no check for whether the thrown expression is a call to `Error.throwWithStackTrace` (or any special-cased static method), and no check of whether an argument derives from the enclosing `CatchClause`'s `StackTrace` parameter. `rethrow` is exempt only incidentally — because `RethrowExpression` is a distinct AST node type that `_ThrowVisitor` never overrides a visitor method for — not because the rule explicitly special-cases it. There is no `visitRethrowExpression` override anywhere in `exception_rules.dart` for this rule.

### On the "redundant throw" question

`Error.throwWithStackTrace` is declared to return `Never`. Per Dart semantics, a `Never`-returning static method can be called as a bare statement (`Error.throwWithStackTrace(newError, stack);`) without a leading `throw` keyword — the call itself never returns, so nothing needs "discarding." The surrounding code comment at the real site (`edits_batch_handler.dart:79`, *"Use as throw operand so the [Never] return is not treated as discarded"*) indicates the `throw` keyword was added specifically to satisfy a **different** diagnostic (an unused/discarded-return-value check), not because Dart requires it.

This matters for root cause, not just style: `_ThrowVisitor.visitThrowExpression` is keyed on the `ThrowExpression` **AST node type**, which is only constructed when the `throw` keyword is present in source. If the same call were written as a bare statement — `Error.throwWithStackTrace(newError, stack);` with no `throw` — there would be no `ThrowExpression` node at all, and `avoid_throw_in_catch_block` would **not** fire on it, despite the runtime behavior being identical. **The rule is reacting to the `throw` token, not to the semantic pattern of "creating a new error while discarding the stack trace."** This means removing the (redundant, per Dart semantics) `throw` keyword would silence this specific lint as a side effect — but that is not the correct fix: it would likely re-trigger whatever discarded-return-value diagnostic the `throw` keyword was added to satisfy in the first place, trading one false positive for another. The correct fix is for `avoid_throw_in_catch_block` to recognize the semantic pattern (`Error.throwWithStackTrace` call, with or without a leading `throw`) rather than keying off the presence of the `throw` token.

---

## Suggested Fix

In `_ThrowVisitor.visitThrowExpression` (`exception_rules.dart:224-227`), before reporting, check whether `node.expression` is a `MethodInvocation`/`FunctionExpressionInvocation` resolving to `Error.throwWithStackTrace` (target `Error`, method name `throwWithStackTrace`, declaring library `dart:core`). If so, suppress the finding — optionally only when the second positional argument is (or textually/structurally derives from) the enclosing `CatchClause`'s `StackTrace` parameter, mirroring the exemption `avoid_throw_in_catch_block`'s own `correctionMessage` (`exception_rules.dart:196-197`) already recommends. Additionally, since `Error.throwWithStackTrace` returns `Never` and can legally appear as a bare statement, verify the rule (or whichever unused-return-value rule motivated the `throw` prefix in the first place) does not force an unnecessary `throw` keyword onto `Never`-returning calls — that keyword is what creates the `ThrowExpression` node this rule keys on.

---

## Fixture Gap

Fixture at `example/lib/exception/avoid_throw_in_catch_block_fixture.dart` (125 lines) mentions `Error.throwWithStackTrace` only in a **comment** (line 123: `throw Exception('Failed: $e'); // Or use Error.throwWithStackTrace`) — there is no actual `throw Error.throwWithStackTrace(...)` test case in the fixture (`grep -n "throwWithStackTrace|rethrow"` finds only that one comment). Should add:

1. **`throw Error.throwWithStackTrace(NewError(...), caughtStackTrace);`** inside a `catch (e, caughtStackTrace)` block — expect NO lint (this bug's exact shape).
2. **`rethrow;`** inside a `catch` block — expect NO lint (should already pass structurally; add explicitly to lock in the behavior via a regression test rather than relying on incidental AST-type exemption).
3. **`throw Exception('new error');`** with no stack-trace forwarding — expect LINT (existing documented bad case, confirm fix doesn't over-exempt plain `throw`).

---

## Finish Report (2026-09-18)

### Verdict

**Valid.** The report's reproduction, AST trace, and root-cause analysis are correct. The suggested fix (recognize the semantic `Error.throwWithStackTrace` call rather than keying off the bare `ThrowExpression` AST node) is exactly what was implemented, without the optional stack-trace-argument-provenance check (see "Scope decision" below).

### Root Cause

`_ThrowVisitor.visitThrowExpression` (`lib/src/rules/flow/exception_rules.dart`, formerly lines 224-227) reported unconditionally on every `ThrowExpression` inside a `catch` block body, with no inspection of the thrown expression. `Error.throwWithStackTrace(...)` — `dart:core`'s documented API for throwing a new error while explicitly preserving an existing `StackTrace`, and the exact pattern this rule's own `correctionMessage` recommends — was therefore flagged as if it were an ordinary stack-trace-discarding `throw`.

### Fix

Added a semantic (resolved-element) guard, `_ThrowVisitor._throwsViaThrowWithStackTrace`, that inspects the thrown expression before reporting:

- Confirms it's a `MethodInvocation` named `throwWithStackTrace` with a `SimpleIdentifier` target literally named `Error` (cheap syntactic pre-filter).
- Resolves `methodName.element`, requires a static `MethodElement`.
- Confirms the resolved element's `library.uri` is `dart:core` — this is what prevents a look-alike, user-defined `Error.throwWithStackTrace` from being silently exempted (a look-alike class that also happens to be named `Error` in the same library will shadow the dart:core one and correctly still be checked against dart:core's element, not the shadow's).

If the match holds, `visitThrowExpression` skips the report; otherwise behavior is unchanged.

**Scope decision:** did *not* implement the optional "verify the second argument derives from the enclosing `CatchClause`'s `StackTrace` parameter" refinement the report suggested as a stretch goal. `Error.throwWithStackTrace` is a general-purpose stack-trace-preserving API — it is legitimate to call it with any `StackTrace` value (e.g., one captured earlier, or `StackTrace.current`), not only the immediately-enclosing catch parameter. Restricting the exemption to only that one syntactic shape would reintroduce false positives for equally valid usages, and the identifier-provenance check (walking through intermediate variables/reassignment) would add real complexity for a purely cosmetic narrowing. The core semantic fix (which API is being called) fully resolves the reported false positive.

The "redundant throw" / bare-statement observation in the report is correct but describes a *separate*, un-filed concern (whatever rule forces `Never`-returning calls into `throw` position) — out of scope for this fix, which only concerns `avoid_throw_in_catch_block`.

### Files Changed

- `lib/src/rules/flow/exception_rules.dart` — added `_throwsViaThrowWithStackTrace` guard in `_ThrowVisitor`.
- `example/lib/exception/avoid_throw_in_catch_block_fixture.dart` — added two GOOD fixture cases: `throw Error.throwWithStackTrace(...)` (this bug's exact shape) and a `rethrow;` control case.
- `test/rules/flow/flow_fp_test.dart` — added group `avoid_throw_in_catch_block — Error.throwWithStackTrace exemption` with 4 resolved-harness tests:
  - does NOT flag `throw Error.throwWithStackTrace(...)`
  - does NOT flag `rethrow` (control)
  - still flags a plain `throw Exception(...)` with no stack-trace forwarding (regression floor)
  - still flags a look-alike, non-`dart:core` `Error.throwWithStackTrace` (confirms the exemption is semantic, not name-based)

### Tests

- `dart analyze lib/src/rules/flow/exception_rules.dart` — no issues found.
- `dart test test/rules/flow/exception_rules_test.dart test/rules/flow/flow_fp_test.dart` — **29 passed, 0 failed** (all pre-existing tests plus the 4 new ones).

### Follow-up (2026-09-18, same day): two review nits fixed

An Opus review of the initial fix found the guard was still incomplete on two edges — both genuine, user-visible gaps in the original semantic check:

1. **Scan CLI's syntactic (unresolved) pass still flagged the exact reported shape.** `_throwsViaThrowWithStackTrace` required a resolved `MethodElement` before exempting anything. The default `saropa_lints scan` runs a syntactic-only pass (see `test/support/syntactic_rule_harness.dart`, which mirrors `ScanRunner._scanSingleFile`) with no type resolution, so `methodName.element` is `null` there — the false positive persisted for that path even though the IDE/resolved path was fixed. **Fix:** when `element == null`, fall back to the syntactic match already established (target name `Error`, method name `throwWithStackTrace`) instead of requiring resolution. When an element *is* resolved, the existing `dart:core` check still applies — no loosening for the resolved path.
2. **`core.Error.throwWithStackTrace(...)` (import-prefixed dart:core) was still flagged.** Target extraction only accepted a bare `SimpleIdentifier`, so a `PrefixedIdentifier` target (e.g. `Error` reached via a prefixed `dart:core` import) was rejected before element resolution even ran. **Fix:** target-name extraction now handles both `SimpleIdentifier` (`target.name`) and `PrefixedIdentifier` (`target.identifier.name`) via a `switch` expression; correctness for the resolved path still comes from the existing `element.library.uri == 'dart:core'` check afterward, so this only widens which *syntax shapes* can reach that check — it does not loosen what counts as a match.

`StackTrace.current` was explicitly out of scope for this follow-up (left unchanged, per review instruction) — it's unrelated to the target/resolution matching above; it's a valid argument to `throwWithStackTrace`'s second parameter and was never the reporting target.

**Files touched (follow-up):**
- `lib/src/rules/flow/exception_rules.dart` — `_throwsViaThrowWithStackTrace`: added the `element == null` fallback and switched target-name extraction to accept `PrefixedIdentifier` as well as `SimpleIdentifier`.
- `test/rules/flow/flow_fp_test.dart` — added import of `../../support/syntactic_rule_harness.dart` and 3 new tests in the `avoid_throw_in_catch_block` group:
  - `syntactic (unresolved) mode does NOT flag throw Error.throwWithStackTrace(...)` (via `reportedRuleCodesSyntactic`, covers case 1 through the actual unresolved path the scan CLI uses)
  - `syntactic (unresolved) mode still flags a plain throw` (regression floor for the syntactic path)
  - `does NOT flag throw core.Error.throwWithStackTrace(...) (prefixed dart:core import)` (resolved harness, covers case 2)

**Tests (follow-up):**
- `dart analyze lib/src/rules/flow/exception_rules.dart test/rules/flow/flow_fp_test.dart` — no issues found.
- `dart test test/rules/flow/exception_rules_test.dart test/rules/flow/flow_fp_test.dart` — **32 passed, 0 failed**.

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

- saropa_lints version: 16.2.1 resolved (findings); 16.3.0 / HEAD (source reviewed for this report — confirmed unchanged for this rule since v16.2.1)
- Dart SDK version: 3.12.2 (stable)
- custom_lint version: n/a (findings from `saropa_lints scan` CLI / VS Code extension)
- Triggering project/file: `saropa_drift_advisor` 4.4.1, `lib/src/server/edits_batch_handler.dart:80`; scan report `saropa_drift_advisor/reports/20260918/20260918_081229_findings.json`
