# PROPOSAL: Flag Bare `await` Inside fpdart `Do`-Notation Blocks

**Status: Open**

Created: 2026-09-02
Type: New rule (package-specific — depends on the `fpdart` functional-programming package)
Related rules: `avoid_ad_hoc_left_type`, `avoid_dollar_outside_do_frame` (sibling fpdart-family proposals)

---

## Summary

Add `avoid_bare_await_in_do` to flag a plain Dart `await someFuture;` expression used inside an `fpdart`
`Do`-notation block (`TaskEither.Do((_) async { ... })` / `Either.Do((_) { ... })`), where the block's own
`_()` extraction operator should be used instead to unwrap monadic values (`TaskEither`, `Either`) and
propagate short-circuiting failures. A bare `await` on a `Future` bypasses `Do`-notation's error-channel
short-circuiting entirely, defeating the reason to use `Do` in the first place.

**Closes gap:** `many_lints` `avoid_bare_await_in_do` (fpdart family). Part of Gap Theme 1 "fpdart /
functional-programming ecosystem" — see `avoid_ad_hoc_left_type` proposal for the shared adoption-decision
framing. Implementing this proposal as specified closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`fpdart`'s `Do`-notation exists specifically to let imperative-looking code short-circuit on the first
`Left`/`None` it encounters, without manual `.flatMap()` chaining. A bare `await` inside the block runs a
raw `Future` outside that mechanism — if it throws, the exception propagates as an uncaught error instead of
becoming a typed `Left`, silently reintroducing the exact untyped-error-propagation problem `Either`-based
error handling was adopted to eliminate.

---

## Detection / Behavior

### Should flag (bad code)

```dart
TaskEither<Failure, User> fetchAndSave(String id) {
  return TaskEither.Do((_) async {
    final response = await http.get(Uri.parse('/users/$id')); // LINT — avoid_bare_await_in_do: bypasses Do-notation short-circuiting; wrap in TaskEither and use _()
    return User.fromJson(response.body);
  });
}
```

### Should pass (good code)

```dart
TaskEither<Failure, User> fetchAndSave(String id) {
  return TaskEither.Do((_) async {
    final response = await _(fetchUserTask(id)); // OK — extraction operator, short-circuits on Left
    return response;
  });
}
```

---

## Proposed Tier

Tier: Comprehensive (package-dependent — see `fpdart` dependency note)
Justification: Only fires in projects depending on `fpdart`; correctness footgun specific to `Do`-notation
usage, matching saropa's placement for other single-package API-usage correctness rules.

---

## Edge Cases

1. **`await` on a genuinely non-monadic Future that has no failure path worth propagating** (e.g. `await
   Future.delayed(...)` used purely for timing) — needs discussion; technically still bypasses the pattern,
   but has no error-channel implication — consider exempting `Future.delayed`/`Future.value` specifically.
2. **`await` outside any `Do` block, in ordinary async code** — should pass; the rule only applies inside the
   lexical scope of a `Do((_) async {...})` callback.
3. **Nested `Do` blocks** (a `Do` block containing another `TaskEither.Do(...)` call awaited via bare
   `await` rather than `_()`) — should flag; the inner `Do`'s result is itself a `TaskEither` that should be
   unwrapped via `_()`, not raw-awaited.
4. **Project does not depend on `fpdart`** — must not fire; gate on package presence like saropa's other
   ecosystem-specific rules.

---

## Alternatives Considered

- See `bugs/tier_4_fpdart/proposal_avoid_ad_hoc_left_type.md` Alternatives Considered — same fpdart-adoption-scope
  discussion applies uniformly across the fpdart-family proposals.

---

## Decision

---

## Implementation Notes

- Shares the `Do`-block AST-containment detection with `avoid_dollar_outside_do_frame` — implement both
  against one shared "is this node inside a `Do(...)` callback" helper.

---

## Commits
