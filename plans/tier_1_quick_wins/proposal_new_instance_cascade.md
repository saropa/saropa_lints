# PROPOSAL: Suggest Cascade Notation for Repeated Calls on a Freshly Constructed Instance

**Status: Implemented**

Created: 2026-09-02
Type: New rule
Related rules: `cascade_invocations` (core lints)

---

## Summary

Add `new_instance_cascade` to flag two or more consecutive statements that each call a method or set a property on the same freshly-constructed local variable, where Dart's cascade (`..`) notation would express the same intent as a single chained expression.

**Closes gap:** `essential_lints` `new_instance_cascade` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Repeating a receiver variable name across several consecutive statements right after construction is pure noise — the reader already knows what `controller` is from the line above and re-reads its name three more times for no new information. Dart's cascade operator collapses this into one expression that reads as "build this object, then configure it", which is both shorter and makes the shared receiver visually obvious.

---

## Detection / Behavior

### Should flag (bad code)

```dart
final controller = TextEditingController();
controller.text = 'hello'; // LINT — repeated calls on freshly-constructed `controller`
controller.selection = const TextSelection.collapsed(offset: 5);
```

### Should pass (good code)

```dart
final controller = TextEditingController()
  ..text = 'hello' // OK — cascade groups the configuration calls
  ..selection = const TextSelection.collapsed(offset: 5);
```

---

## Proposed Tier

Tier: Pedantic
Justification: purely stylistic preference between two equally correct forms; belongs in the opt-in tier alongside other cascade/chaining style rules.

---

## Edge Cases

1. **A statement between the calls that reads the variable's return value or reassigns another variable** — should pass; cascades can't interleave with unrelated statements that consume an intermediate result.
2. **Only one statement calls the receiver after construction** — should pass; cascade adds no value for a single call.
3. **Receiver reassigned between the construction and the calls** — should pass; not a fresh-instance cascade opportunity anymore.
4. **Calls span an `if`/`for` control-flow block** — should pass; cascade cannot cross control-flow boundaries.

---

## Alternatives Considered

- **Also flag single-statement cases where the constructor call itself could inline a cascade of length 1** — rejected; no readability benefit for a single call, and it would fire far too often for a purely cosmetic gain.

---

## Decision

---

## Implementation Notes

---

## Commits

## Finish Report (2026-09-04)

### Issues

- **Suggests a transformation that can fail to compile when the RHS/args self-reference the receiver** (`new_instance_cascade_rules.dart:33-58`, `_isFreshInstanceConfigStatement`). The matcher only inspects the *left-hand side* of an assignment (`lhs is PropertyAccess`/`PrefixedIdentifier` rooted at `varName`) or the *target* of a method call — it never inspects the RHS expression or call arguments. `controller.selection = TextSelection.collapsed(offset: controller.text.length);` matches and would combine with a sibling statement into a cascade candidate, but folding it into `final controller = TextEditingController()..selection = TextSelection.collapsed(offset: controller.text.length);` references `controller` inside its own initializer, which is a compile error (self-reference before the variable is bound). Same trap applies to method-call arguments (`controller.jumpTo(controller.offset);`). Not caught by any test or fixture case. Because there is no auto-fix (INFO-only, manual rewrite), the practical harm is a bad suggestion rather than a broken auto-fix, but it should still be excluded — walk the RHS/argument list for any reference to `varName` and bail if found.
- **False negative: an initializer that is already partially cascaded stops all further detection for that variable**, even when later, un-cascaded statements exist. `if (initializer is! InstanceCreationExpression) continue;` (line 171) treats any `CascadeExpression` initializer as "nothing left to suggest," but `final c = Ctrl()..text = 'a'; c.selection = sel; c.other = x;` still has two consecutive un-cascaded configuring statements that are a legitimate cascade opportunity — the rule stays silent. Not covered by the proposal's edge cases or by any test.

### Concerns

- **Name-based matching, not identifier-resolution-based.** `target.name == varName` / `lhs.prefix.name == varName` compare `SimpleIdentifier.name` strings, not resolved elements. Within a single `Block`'s direct statement list this is safe today (Dart scoping prevents a same-named different variable being reachable as a bare identifier in the same block after the declaration), but the safety is incidental to the current "single block, consecutive siblings only" restriction. If detection is ever broadened (e.g., to look into nested blocks, or across closures), this string comparison would need to become an element-identity check to stay sound.
- **`runWithReporter` is at/over the project's 50-line function cap.** Lines 145-195 span ~51 lines including signature and closing braces. It is not egregious, but the self-reviewer threshold is a hard line elsewhere in this codebase; consider extracting the inner "count consecutive configuring statements starting at `i+1`" loop into a small helper (e.g. `_countConsecutiveConfigStatements(statements, i, varName)`) both to get under the cap and to make the two nested loops easier to read independently.
- No quick fix is offered (rule is advisory/INFO-only). Reasonable given the RHS-self-reference hazard above — an auto-fix would need the same self-reference guard to be safe, so leaving it manual sidesteps that risk for now, but it does mean the "Opportunities" auto-fix suggestion below is blocked on fixing the Issues section first.

### Opportunities

- The RHS/argument self-reference check needed to close the Issues-section bug above could reuse whatever "does this subtree reference identifier X" helper already exists elsewhere in the codebase (several rules need a "target read after write" or "self-reference" check) — worth checking `lib/src/` utilities before hand-rolling a new AST-walking visitor for it.
- Once the self-reference guard exists, this rule becomes a safe candidate for a real quick fix (splice the matched statements' RHS/args into `..` cascade sections appended to the constructor call) rather than staying suggestion-only — but only after the guard lands, not before.

### Recommendations

1. **(High)** Add the self-reference guard in `_isFreshInstanceConfigStatement` (or a new helper it calls) so a statement whose RHS/arguments reference `varName` is excluded from matching. Add a fixture/test case (`controller.selection = TextSelection.collapsed(offset: controller.text.length);` as the second of two configuring statements) proving the rule stays silent.
2. **(Medium)** Extend detection to keep scanning after a `CascadeExpression` initializer, so two or more un-cascaded trailing statements are still flagged even when the declaration already carries a partial cascade. Add a fixture/test case for it.
3. **(Low)** Extract the inner consecutive-statement-counting loop out of `runWithReporter` into a named helper to bring the function back under the 50-line guideline and match the file's existing helper-function style (`_isFreshInstanceConfigStatement`).
4. **(Low)** Add a regression test for 3+ consecutive configuring statements to lock in the "report once, at the first match, don't re-report for the tail" behavior that the `count >= 2` break already relies on but nothing currently asserts against a longer run.
