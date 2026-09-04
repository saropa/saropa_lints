# PROPOSAL: Flag Builder Callbacks That Never Use Their `BuildContext` Parameter

**Status: Implemented**

Created: 2026-09-02
Type: New rule
Related rules: `use_build_context_synchronously`

---

## Summary

Add `never_discard_build_context` to flag a `BuildContext` parameter supplied by a builder callback (`WidgetBuilder`, `TransitionBuilder`, `Builder(builder: (context) => ...)`, `Consumer`'s `context`, etc.) that is never read inside the callback body. A builder callback exists specifically to hand the caller a *scoped* context — ignoring it and reaching for an outer/ambient context instead usually means the widget loses the intended `InheritedWidget` scope (theme, localization, provider) that the builder was set up to provide.

**Closes gap:** `leancode_lint` `never_discard_build_context` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`Builder(builder: (context) => Text(Theme.of(context).primaryColor.toString()))` exists because the outer `context` doesn't yet see the widget being built. When a developer writes the callback but reads a captured outer `context` instead of the parameter, the bug is invisible until the value resolves to the wrong scope at runtime (wrong theme, wrong localization, stale `Provider`/`InheritedWidget` value). Flagging the unused parameter catches the mistake at write time.

---

## Detection / Behavior

### Should flag (bad code)

```dart
Widget build(BuildContext context) {
  return Builder(
    builder: (innerContext) { // LINT — `innerContext` is declared but never read
      return Text(Theme.of(context).primaryColor.toString()); // uses outer `context` instead
    },
  );
}
```

### Should pass (good code)

```dart
Widget build(BuildContext context) {
  return Builder(
    builder: (innerContext) {
      return Text(Theme.of(innerContext).primaryColor.toString()); // OK — uses the scoped context
    },
  );
}
```

---

## Proposed Tier

Tier: Recommended
Justification: catches a real, hard-to-spot scoping bug in common Flutter builder patterns without requiring any package beyond Flutter itself.

---

## Edge Cases

1. **Builder body has no need for any `InheritedWidget`/theme lookup at all (e.g. returns a constant widget)** — needs discussion; a context param that is genuinely unusable should be renamed `_` rather than flagged, so the rule should treat `_`-prefixed unused params as intentional and pass.
2. **Nested builders where the inner builder's context is used but the outer's is not** — should flag the outer builder only if its own context parameter goes unused within its own callback body (excluding nested callback bodies).
3. **`StatefulBuilder`'s `setState` parameter combined with an unused `context`** — should still flag the unused `context`; `setState` being used doesn't excuse ignoring `context`.
4. **Context captured into a variable and used later in the same callback** — should pass; the rule checks for any read, not just direct inline use.

---

## Alternatives Considered

- **Require renaming unused context params to `_`** — deferred as a quick fix, not the detection rule itself; detection should fire regardless of whether the offending code is expected to eventually rename or actually use it.

---

## Decision

---

## Implementation Notes

---

## Commits

## Finish Report (2026-09-04)

### Issues

1. **Confirmed false positive: context used only inside a nested non-builder closure is not detected as a "use," so the rule fires on correct code.** `_IdentifierUsageVisitor.visitFunctionExpression` (both `lib/src/rules/widget/never_discard_build_context_rules.dart:206-210` and its manual mirror in `test/rules/widget/never_discard_build_context_test.dart:320-323`) stops descending into **every** nested `FunctionExpression`, not just nested builder callbacks. The doc comment and proposal edge case 2 only justify skipping a *nested builder's own context parameter*, but the code applies the same skip to any closure at all — `onPressed`, `onTap`, `then()`, `catchError()`, `addPostFrameCallback`, `Future.delayed`, `Timer` callbacks, etc. Verified empirically by running the rule's exact detection logic (copied from the test file) against:
   ```dart
   Builder(
     builder: (BuildContext ctx) {
       return ElevatedButton(
         onPressed: () { Navigator.of(ctx).pop(); },
         child: Text('Close'),
       );
     },
   )
   ```
   Result: `reported=true` — the rule flags `ctx` as unused even though it is read inside `onPressed`. This is one of the single most common real-world uses of a builder-scoped context (deferring a `Navigator`/`ScaffoldMessenger`/`showDialog` call to a button callback) and will fire constantly on correct code.

2. **Same defect via `visitFunctionDeclarationStatement`** (`never_discard_build_context_rules.dart:212-215`): a local named function declared inside the builder body (`void handleTap() { Navigator.of(ctx).pop(); }`) that reads the context is likewise invisible to the usage scan — same false positive, different syntax.

3. Neither gap is covered by the fixture (`example/lib/widget_lifecycle/never_discard_build_context_fixture.dart`) or the unit tests (`test/rules/widget/never_discard_build_context_test.dart`) — the only nested-closure test (lines 166-188) covers exclusively the case where the nested closure is *itself* a builder declaring its *own* context param, which is a narrower and different scenario from "context used inside an arbitrary nested callback."

### Concerns

- **Tier mismatch between proposal and implementation.** The proposal states "Tier: Recommended" (line 55), but `never_discard_build_context` is registered in `essentialRules` in `lib/src/tiers.dart:782`, not `recommendedOnlyRules`. Given issue #1 above, shipping this in Essential — the tier enabled by default with the least tolerance for false positives — is higher-risk than the proposal anticipated. The "Decision" and "Implementation Notes" sections of this proposal are empty, so there's no recorded rationale for the tier bump.
- The manual duplication of the rule's detection logic in the test file (`_BuilderCallbackVisitor`/`_IdentifierUsageVisitor`, lines 240-329) is explicitly flagged in its own doc comment as "kept in sync manually" — this is exactly how issue #1 could silently diverge between rule and test in the future (a fix to the rule's visitor needs a parallel fix in the test mirror, easy to forget).
- The untyped-name allow-list (`_untypedContextNames`) is a deliberate, documented trade-off (avoids `.contains()`-based name guessing) but means any untyped context parameter using a name outside the six listed (e.g. `theContext`, `c`, `scopedContext`) is silently invisible to the rule — a false negative, not tested either way.
- Only the first parameter of the `builder:` callback is ever examined. This is correct for `Builder`/`LayoutBuilder`/`StatefulBuilder`/`FutureBuilder`/`StreamBuilder`, but the rule doesn't handle a `builder:` callback assigned from a separate named function/tear-off/variable (`Builder(builder: someExistingFunction)`) since `node.parent` there is never reached via the `FunctionExpression` visitor at all — an accepted false-negative gap, not a bug.

### Opportunities

- Fix the closure-boundary logic in `_IdentifierUsageVisitor` to only stop at a nested `FunctionExpression`/`FunctionDeclarationStatement` when that nested function itself redeclares a parameter/local with the **same name** as `targetName` (true shadowing) — otherwise keep descending. This directly resolves both Issues #1 and #2 while still preserving the intent of proposal edge case 2 (a nested builder using its own same-named context should not count as a use of the outer one).
- Once the rule logic changes, delete the manually-duplicated visitor in the test file and instead exercise `NeverDiscardBuildContextRule` directly (or via the scan CLI per `reference_verify_rule_behavior_scan_cli.md`) so the test can never drift from the implementation again.
- Add fixture + unit-test coverage for the "context passed into a nested non-builder callback" pattern (button `onPressed`, `Future.then`, `addPostFrameCallback`) as both a GOOD case (must not fire) once fixed, and to lock in the fix as a regression test.
- Reconcile the tier: either move the rule to `recommendedOnlyRules` to match the proposal until the false-positive is fixed, or update the proposal's "Proposed Tier" and add a one-line "Decision" note explaining the Essential placement.

### Recommendations

1. **(High)** Fix `_IdentifierUsageVisitor` to not blanket-skip nested closures — only skip on genuine same-name shadowing — before this rule ships broadly; the current behavior will false-positive on a very common Flutter pattern (context handed to a button/callback inside a builder).
2. **(High)** Add regression tests/fixture entries for the nested-callback-uses-context pattern once fixed.
3. **(Medium)** Either downgrade the tier to Recommended (matching the proposal) until #1 is fixed, or explicitly document the decision to ship it in Essential despite the known gap.
4. **(Low)** Replace the test file's manually-duplicated detection visitor with a direct call into `NeverDiscardBuildContextRule`'s own logic (or expose the helpers for reuse) to prevent future drift between rule and test.
