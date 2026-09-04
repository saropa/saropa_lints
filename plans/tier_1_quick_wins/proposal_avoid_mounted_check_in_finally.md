# PROPOSAL: Flag `mounted` Checks Placed Inside a `finally` Block

**Status: Implemented**

Created: 2026-09-02
Type: New rule
Related rules: `require_mounted_check_after_await` (existing, DCM-parity extension)

---

## Summary

Add `avoid_mounted_check_in_finally` to flag `if (mounted)` / `if (!mounted) return;` checks placed inside a `finally` block following an `await` in `State` lifecycle/callback code — a `finally` block always runs, including after the widget has already been disposed and even along exception paths, so gating a `setState`/navigation call there on `mounted` gives a false sense of safety: the check runs, but by the time it does, other cleanup in the same `finally` may already have executed unconditionally before it.

**Closes gap:** flutter_skill_lints `avoid_mounted_check_in_finally`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`mounted` checks exist to guard against calling `setState()`/`Navigator` operations after a widget's `State` has been disposed following an `await`. Placing that guard inside `finally` is a common but broken pattern: statements in `finally` above the `mounted` check still execute unconditionally regardless of disposal state, and the developer's mental model ("finally always runs, so this is the safe place to check") is backwards — the check needs to happen at the point of use, immediately after each `await`, not bundled into a single end-of-block gate.

---

## Detection / Behavior

Flag an `if` statement testing `mounted` (or `!mounted`) whose nearest enclosing block is a `finally` clause of a `try`/`finally` inside a `State` subclass method.

### Should flag (bad code)

```dart
Future<void> _submit() async {
  setState(() => _isLoading = true);
  try {
    await _api.submit(_formData);
  } finally {
    _controller.dispose(); // Runs unconditionally, even if unmounted
    if (mounted) { // LINT — mounted check in finally gives false confidence
      setState(() => _isLoading = false);
    }
  }
}
```

### Should pass (good code)

```dart
Future<void> _submit() async {
  setState(() => _isLoading = true);
  try {
    await _api.submit(_formData);
  } finally {
    _controller.dispose();
  }
  if (!mounted) return; // OK — checked immediately after the await, at point of use
  setState(() => _isLoading = false);
}
```

---

## Proposed Tier

Tier: Recommended
Justification: A `mounted`-after-`await` bug is a real crash/error risk ("setState called after dispose"); this rule catches a specific misplaced-guard variant of that class of bug, warranting broader default-on placement similar to the existing `require_mounted_check_after_await` rule.

---

## Edge Cases

1. **`mounted` check inside `finally` that gates the *entire* finally body (nothing runs unconditionally above it)** — needs discussion; still recommend flagging by default, since a later edit adding an unconditional statement above the check would silently reintroduce the bug with no lint signal at that edit site.
2. **`if (mounted)` inside `finally` used only to log a diagnostic (no `setState`/navigation)** — should pass; the risk is specifically unsafe widget-tree operations after disposal, not diagnostic checks.
3. **`try`/`finally` with no `await` inside the `try` block** — should pass; the `mounted` concern only applies after crossing an async gap.
4. **`mounted` check in `finally` inside a `StatefulWidget` helper method that is itself called from multiple places, some without a preceding `await`** — should still flag; the pattern is unsafe regardless of caller.

---

## Alternatives Considered

- **Ban `finally` blocks entirely in async `State` methods** — rejected; `finally` is legitimate for unconditional cleanup (disposing controllers, resetting flags) — the rule targets the specific `mounted` guard placement, not `finally` usage in general.

---

## Decision

---

## Implementation Notes

---

## Commits

## Finish Report (2026-09-04)

### Issues

- **Tier mismatch**: the proposal specifies "Tier: Recommended" (line 64), but
  `lib/src/tiers.dart` line 781 places `'avoid_mounted_check_in_finally'` in
  `essentialRules` (the set spans lines 311-788), not `recommendedOnlyRules`
  (which starts at line 788). Essential is broader/more default-on than what
  was proposed and decided — needs a decision on whether the implementation
  or the proposal is wrong, and the doc/tier corrected to match.
- **False negative — await only in a `catch` clause**: `_containsAwait`
  (`avoid_mounted_check_in_finally_rules.dart` lines 185-192) only inspects
  `tryStatement.body`, never `tryStatement.catchClauses`. A real async gap
  created by `try { syncOp(); } catch (e) { await recover(); } finally { if
  (mounted) { setState(...); } } }` is missed entirely — the exact bug class
  the rule targets, undetected because the `await` happened in the `catch`
  branch instead of the `try` body. Not covered by any test.
- **Stale/incorrect test-file comment**: `test/rules/widget/avoid_mounted_check_in_finally_test.dart`
  lines 3-8 assert "The rule is not yet wired into the global tier registry
  (a separate process handles the three-way registration centrally...)". This
  is factually false: the rule IS registered in all three required places —
  `lib/src/rules/all_rules.dart:217` (export), `lib/saropa_lints.dart:2932`
  (`AvoidMountedCheckInFinallyRule.new` in `_allRuleFactories`), and
  `lib/src/tiers.dart:781` (essentialRules). The comment should be corrected
  or removed; as written it will mislead the next person who touches this
  file into thinking registration is still pending.

### Concerns

- **Message text overclaims when nothing precedes the guard**: the lint
  message ("...so any statement written above this guard in the same block
  still executes unconditionally...") and the class doc's rationale assume
  there is unconditional cleanup code above the `mounted` check. Edge case 1
  in the proposal (guard is the only statement in `finally`) is still flagged
  by design, but the message text doesn't hold in that shape — nothing
  actually ran unconditionally "above" it. Not a false positive by the
  proposal's own stated policy (edge case 1 says "still recommend flagging by
  default"), but the message could confuse a developer staring at a
  `finally` block whose *only* content is the guard.
  `example/lib/widget/avoid_mounted_check_in_finally_fixture.dart` has no
  fixture for this specific shape (only-statement-in-finally with an unsafe
  op) to pin the intended behavior.
  `avoid_mounted_check_in_finally_rules.dart` shape 2 detection
  (`_followingSiblingsGuardUnsafeOperation`, lines 265-277) scans every
  statement following the guard in the same block for an unsafe call,
  regardless of intervening unrelated control flow (e.g. an unrelated `if
  (someOtherCondition) { setState(...); }` after the guard). This is broad by
  design per the proposal ("pattern is unsafe regardless of caller", edge
  case 4) but is the most syntactically loose part of the detector and worth
  watching if FP reports come in.
- **Lexeme-based type matching for `Navigator`/`ScaffoldMessenger`**
  (`_unsafeTargetNames`, lines 212-215, via `extractTargetName`/`_rootTargetName`)
  is unresolved-type matching, not a real type check — a user-defined class
  literally named `Navigator` would false-positive. This mirrors an existing,
  accepted pattern elsewhere in the codebase (`isExactTarget` in
  `target_matcher_utils.dart`), so it's a known, deliberate trade-off rather
  than a new defect, but it is a fragile point if this rule's scope grows.
  Same applies to `isWidgetOrStateClass` (lexeme suffix match on `Widget`/
  `State`), explicitly noted as intentional in the test file's own header
  comment (lines 10-14) because the harness has no Flutter dependency to
  resolve against.
- **`_unsafeMethodNames`/`_unsafeTargetNames` are hand-maintained allow-lists**
  (lines 198-215) covering only `setState` + a handful of dialog/overlay
  `show*` calls + `Navigator`/`ScaffoldMessenger`. Common unsafe-after-dispose
  patterns like `context.go(...)`/`context.push(...)` (go_router),
  `Overlay.of(context)`, or a `ValueNotifier`/`ChangeNotifier` `.notifyListeners()`
  call are false negatives by omission — acceptable narrowing per the
  false-positive doctrine, but worth listing as known scope limits if this
  rule gets a follow-up.

### Opportunities

- None identified beyond what's listed under Recommendations — the visitor
  already reuses `isWidgetOrStateClass` and `extractTargetName` from
  `target_matcher_utils.dart` rather than reimplementing widget-class/target
  detection, consistent with the project's "search before creating" rule.

### Recommendations

1. **Resolve the tier mismatch** (Issues #1) — either move
   `'avoid_mounted_check_in_finally'` from `essentialRules` to
   `recommendedOnlyRules` in `lib/src/tiers.dart`, or update this proposal's
   "Proposed Tier" section to say Essential and justify the stronger
   placement. Do this before the tier is relied on by any published docs
   (ROADMAP.md, tier count badges).
2. **Fix the false negative for await-in-catch** (Issues #2) — extend
   `_containsAwait` to also walk `tryStatement.catchClauses` (each
   `CatchClause.body`), and add a fixture + test case:
   `try { x = 1; } catch (e) { await recover(); } finally { if (mounted) { setState(...); } }`
   should fire.
3. **Correct the test file header comment** (Issues #3) — remove or rewrite
   the "not yet wired into the global tier registry" claim in
   `test/rules/widget/avoid_mounted_check_in_finally_test.dart` lines 3-8 now
   that registration is confirmed complete in all three files.
4. **Add missing test/fixture coverage** (Concerns) — at minimum: (a) a
   compound condition `if (mounted && x)` inside `finally` that should NOT
   fire (documented as out of scope at lines 104-107 of the rule but never
   asserted by a test); (b) a `ScaffoldMessenger.of(context).showSnackBar(...)`
   or `showDialog(...)` case to exercise the parts of `_unsafeMethodNames`/
   `_unsafeTargetNames` beyond `setState`/`Navigator`; (c) a nested-closure
   case inside `finally` (e.g. `finally { Future(() async { if (mounted) { setState(...); } }); }`)
   to confirm the `FunctionExpression` boundary in `_enclosingFinallyBlock`
   correctly excludes it.
