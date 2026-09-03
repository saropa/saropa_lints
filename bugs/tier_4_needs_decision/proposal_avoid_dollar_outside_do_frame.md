# PROPOSAL: Flag fpdart `Do`-Notation's `_()` Extraction Operator Used Outside Its `Do` Block

**Status: Open**

Created: 2026-09-02
Type: New rule (package-specific — depends on the `fpdart` functional-programming package)
Related rules: `avoid_ad_hoc_left_type`, `avoid_bare_await_in_do` (sibling fpdart-family proposals)

---

## Summary

Add `avoid_dollar_outside_do_frame` to flag `fpdart` `Do`-notation's extraction callback (conventionally
bound to `_` or `$`, depending on `fpdart` version) being captured and invoked outside the lexical scope of
the `Do(...)` block it was provided to — e.g. stored in a variable and called later, or passed into a nested
closure that escapes the `Do` frame. The extraction operator is only valid for the duration of that single
synchronous/async `Do` callback's execution; using it outside that frame is undefined/unsafe per `fpdart`'s
own contract.

**Closes gap:** `many_lints` `avoid_dollar_outside_do_frame` (fpdart family). Part of Gap Theme 1 "fpdart /
functional-programming ecosystem" — see `avoid_ad_hoc_left_type` proposal for the shared adoption-decision
framing. Implementing this proposal as specified closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`Do`-notation's extraction parameter is a scoped capability, not a general-purpose function: it exists to
unwrap monadic values only within the single callback `fpdart` invokes it in. Capturing it (assigning to an
outer variable, closing over it in a callback that outlives the `Do` block) is a misuse pattern the library
cannot prevent at compile time via Dart's type system alone, making it exactly the kind of package-specific
contract violation a dedicated lint exists to catch.

---

## Detection / Behavior

### Should flag (bad code)

```dart
late Future<User> Function(TaskEither<Failure, User>) extractLater;

TaskEither<Failure, void> process() {
  return TaskEither.Do((_) async {
    extractLater = _; // LINT — avoid_dollar_outside_do_frame: extraction operator captured outside its Do block
  });
}
```

### Should pass (good code)

```dart
TaskEither<Failure, User> process() {
  return TaskEither.Do((_) async {
    return await _(fetchUserTask()); // OK — used only within the Do callback's own scope
  });
}
```

---

## Proposed Tier

Tier: Comprehensive (package-dependent — see `fpdart` dependency note)
Justification: Only fires in projects depending on `fpdart`; correctness footgun specific to `Do`-notation's
scoping contract, matching saropa's placement for other single-package API-usage correctness rules.

---

## Edge Cases

1. **The extraction parameter passed as an argument to another function called synchronously WITHIN the
   same `Do` block** (`_(await someHelper(_))`) — should pass; still within the frame's lifetime, just
   threaded through a helper rather than used directly inline.
2. **Assigned to a local variable used only within the same `Do` block, never escaping it**
   (`final ext = _; ... await ext(task);`) — needs discussion; technically still safe since it doesn't
   escape the frame, but obscures the scoping contract — consider flagging as a lower-confidence style
   warning rather than the same severity as a genuine escape.
3. **Passed into a nested closure that IS invoked synchronously within the same `Do` call, never stored or
   returned** — should pass; the closure doesn't outlive the frame even though it captures the operator.
4. **Project does not depend on `fpdart`** — must not fire; gate on package presence like saropa's other
   ecosystem-specific rules.

---

## Alternatives Considered

- See `bugs/tier_4_needs_decision/proposal_avoid_ad_hoc_left_type.md` Alternatives Considered — same fpdart-adoption-scope
  discussion applies uniformly across the fpdart-family proposals.

---

## Decision

---

## Implementation Notes

- Shares the `Do`-block AST-containment detection with `avoid_bare_await_in_do` — implement both against one
  shared "is this node inside a `Do(...)` callback, and does this reference escape it" helper. Escape
  detection (assignment to an outer-scoped variable, return, storage in a field/collection) is the harder
  half of this rule and should reuse any existing saropa closure-escape-analysis utility if one exists.

---

## Commits
