# prefer_single_setstate — False Positive: counts setState across independent closures in one method

- **Status:** Fixed
- **Created:** 2026-06-03
- **Rule:** `prefer_single_setstate`
- **Rule class:** `PreferSingleSetStateRule` (`lib/src/rules/widget/build_method_rules.dart`, code at line 809)
- **Severity:** INFO
- **Rule version:** v2
- **Reported from:** `D:\src\contacts\lib\components\home\components\welcome_screen.dart` (method `_buildPermissionDenied`; two `setState`s in two separate `onPressed` callbacks)

## Summary

The rule counts every `setState` invocation anywhere in a method body — including inside distinct, independently-invoked closures (e.g. two different buttons' `onPressed` handlers) — and flags the method when the total is >1. Those calls can never be merged: they run on different user actions at different times. The premise "multiple setState in the same method → combine them" only holds for calls in the same synchronous execution path.

## Attribution Evidence

```
$ grep -rln "prefer_single_setstate" D:/src/saropa_lints/lib/src/rules/
lib/src/rules/widget/build_method_rules.dart
```
Not a rule definition in saropa_drift_advisor.

## Reproducer

```dart
// Not named `build`, so not skipped. Two setStates, two SEPARATE closures.
// Currently FIRES on the first setState (false positive).
Widget _buildDeniedView() {
  return Column(children: <Widget>[
    ElevatedButton(
      onPressed: () => setState(() => _a = false), // LINT (should be OK)
      child: const Text('Retry'),
    ),
    ElevatedButton(
      onPressed: () => setState(() => _b = false), // independent callback
      child: const Text('Settings'),
    ),
  ]);
}

// True positive — two setStates in ONE synchronous path; SHOULD fire.
void _onTap() {
  setState(() => _a = 1);
  setState(() => _b = 2); // these two can and should be merged
}
```

## Expected vs Actual

| Two setStates located in… | Expected | Actual |
|---|---|---|
| two separate `onPressed`/callback closures | OK | **LINT (FP)** |
| the same synchronous method body | LINT | LINT |

## Root Cause

`runWithReporter` (build_method_rules.dart ~821–840) runs `_SetStateCountVisitor` (a `RecursiveAstVisitor`) over the whole method body and increments on every `setState` `MethodInvocation`, descending into nested function expressions. It does not distinguish setStates that share an execution scope from setStates in distinct closures, so two callbacks each with one `setState` are counted as 2 and flagged at the first.

## Suggested Fix

When counting, do not descend into nested `FunctionExpression` bodies that are themselves callback values (e.g. stop recursion at `FunctionExpression` boundaries, or count per-closure and only flag when a single closure/synchronous block has >1). A method whose multiple setStates each live in a separate closure should not fire; only multiple setStates within one closure/synchronous block should.

## Fixture Gap

Add a GOOD case: a non-`build` method returning a widget tree with two buttons, each `onPressed` calling `setState` once — must NOT lint. Keep the existing BAD case of two setStates in one synchronous body.

## Environment

- saropa_lints: 13.11.10 (contacts consumes `^13.11.9`)
- Dart SDK `>=3.10.7 <4.0.0`; Flutter `>=3.44.0`
- Native `analysis_server_plugin` (IDE only)
- Triggering file: `D:\src\contacts\lib\components\home\components\welcome_screen.dart`

## Fix (2026-06-03)

`PreferSingleSetStateRule.runWithReporter` (`lib/src/rules/widget/build_method_rules.dart`) now counts `setState` per execution scope instead of across the whole method body. The method body and every nested `FunctionExpression` are treated as independent scopes via a worklist: `_SetStateCountVisitor` counts `setState` calls in the current scope and, on encountering a nested closure, defers it (`onNestedClosure`) rather than descending. A diagnostic fires only when a single scope has more than one `setState`.

Rule version bumped v2 → v3; message updated to say "same execution scope" and note separate-closure calls are not flagged.

Verified with the scan CLI on a `State<>`-classified fixture:
- two `setState` in one synchronous body → **fires** (true positive kept)
- two `setState` in one closure → **fires** (true positive kept)
- two `setState` in two separate `onPressed` closures → **clean** (FP fixed)

Fixture: added the separate-closures GOOD case to `example/lib/build_method/prefer_single_setstate_fixture.dart`. CHANGELOG `[Unreleased] → Fixed` updated.

## Finish Report (2026-06-03)

**Scope:** (A) Dart lint rule / analyzer plugin.

**Deep review.** The fix replaces a single whole-body `RecursiveAstVisitor` count with a worklist of independent scopes. No recursion risk: the worklist is finite (one entry per `FunctionExpression` in the method, each visited once, never re-added). No race conditions (synchronous AST walk). `LintImpact` unchanged (`warning`); tier unchanged (`recommendedOnlyRules`, rule name unchanged). No quick fix added — merging `setState` calls is not mechanically safe (the bodies may have ordering or conditional dependencies), so an auto-fix would risk changing behavior; left to the developer, consistent with the rule's pre-existing no-fix design.

**Logic.** `runWithReporter` seeds `scopes` with `node.body`; for each scope it runs `_SetStateCountVisitor`, which counts `setState` invocations directly in that scope and defers nested `FunctionExpression`s (via `onNestedClosure: scopes.add`) instead of descending. Fires at the first `setState` of the first scope whose count exceeds one. This correctly distinguishes "two setStates in one synchronous path / one closure" (still flagged) from "two setStates in two distinct closures" (no longer flagged).

**Tests.** `test/rules/widget/build_method_rules_test.dart` (instantiation pin + fixture-existence) — 22/22 pass. `test/integrity/saropa_lints_test.dart` — pass (validates message `[rule_name]` prefix, >200 chars, tier membership). No existing test pinned the old message text or behavior, so none required rewriting. Behavior verified end-to-end with the scan CLI on a `State<>`-classified fixture (custom_lint CLI is non-functional in this repo; the scan CLI is the behavior oracle):
- two `setState` in one synchronous body → fires (line 12)
- two `setState` in one closure → fires (line 33)
- two `setState` in two separate `onPressed` closures → clean

**Maintenance.** CHANGELOG `[Unreleased] → Fixed` entry added. ROADMAP has no entry for this rule (nothing to update). README rule counts unchanged. No new utilities (CODE_INDEX unchanged). No structural changes (CODEBASE_INDEX unchanged).

**Files changed:**
- `lib/src/rules/widget/build_method_rules.dart` — per-scope counting, visitor gains `onNestedClosure`, doc + message v2→v3
- `example/lib/build_method/prefer_single_setstate_fixture.dart` — separate-closures GOOD case
- `CHANGELOG.md` — Fixed entry
- `bugs/prefer_single_setstate_false_positive_independent_closures.md` — status Fixed + this report (archived to `plans/history/2026.06/2026.06.03/`)

**Outstanding work:** none.
