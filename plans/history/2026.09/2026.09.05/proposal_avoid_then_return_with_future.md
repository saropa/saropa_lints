# PROPOSAL: Flag Redundant `.then()` Identity/Constant Callbacks on `Future`

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `avoid_then_return_with_future` to flag `Future.then()` calls whose callback is a no-op transform — either an identity function (`.then((value) => value)`) that returns the input unchanged, or a callback that ignores its argument and returns a fixed value/constant when the surrounding code never uses the resulting Future's value. Both patterns add a layer of indirection that produces the exact same `Future` as simpler, more direct code.

**Closes gap:** `flutter_skill_lints` `avoid_then_return_with_future` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`.then((value) => value)` is a common copy-paste leftover from refactoring — someone had a real transform in the callback, simplified the logic until it became an identity function, and never deleted the now-pointless `.then()` wrapper. It compiles, it works, and it is completely invisible in a diff review because nothing is *wrong* — it is just dead weight that makes the reader stop and check whether the callback actually does something. The constant-return variant (`.then((_) => someConstant)` where the constant Future value is never consumed) is the same problem from the other direction: a whole `Future` chain exists to produce a value nobody reads. Both are mechanically detectable and both have a strictly simpler equivalent, making this a safe, high-confidence lint.

---

## Detection / Behavior

### Should flag (bad code)

```dart
Future<int> loadCount() {
  return fetchCount().then((value) => value); // LINT — identity callback, .then() does nothing
}

Future<void> saveAndIgnore() async {
  await repository.save(data).then((_) => true); // LINT — return value discarded by caller, .then() unnecessary
}
```

### Should pass (good code)

```dart
Future<int> loadCount() {
  return fetchCount(); // OK — no redundant .then() wrapper
}

Future<void> saveAndIgnore() async {
  await repository.save(data); // OK — awaited directly, nothing discarded through a pointless .then()
}

Future<int> loadDoubled() {
  return fetchCount().then((value) => value * 2); // OK — callback performs a real transform
}
```

---

## Proposed Tier

Tier: Recommended
Justification: Purely a readability/dead-code cleanup with no correctness risk and a mechanical, low-false-positive detection (identity lambda body, or ignored-parameter callback whose return value provably has no consumer) — matches the tier of other no-op-detection rules in `code_quality_avoid_rules.dart`.

---

## Edge Cases

1. **`.then((value) => value)` where the block body does more than one statement before returning the same value unchanged** (e.g. `.then((value) { print(value); return value; })`) — should pass; the callback has an observable side effect, so it is not a pure no-op even though the return value is unchanged.
2. **`.then<T>((value) => value)` with an explicit generic type argument that differs from the Future's natural type** (a deliberate cast/widen) — needs discussion; if the generic argument changes the static type this may be intentional and should pass, but if it matches the inferred type it is still a no-op and should flag.
3. **`.then((_) => value)` where `value` is used by a caller chaining further `.then()`/`await` on the result** — should pass; the rule must only flag the constant-return variant when the produced Future's value is provably unconsumed (e.g. the `.then()` call is itself the tail expression of a `void`/discarded statement), not just because the callback ignores its parameter.
4. **`.then(print)` or other tear-off callbacks (not a lambda)** — should pass; the rule targets lambda bodies specifically, since a tear-off is not the identity/constant-no-op pattern being detected.
5. **`onError` callback supplied alongside a no-op `then` body** (`.then((value) => value, onError: ...)`) — should still flag the `then` body itself as redundant; suggest restructuring with `catchError`/try-catch around a direct call instead.

---

## Alternatives Considered

- **Also flag `.then((value) => value)` chained mid-pipeline (not just as a tail expression)** — included as in-scope; the identity-callback case is unconditionally a no-op regardless of position, unlike the constant-return case which depends on whether the result is consumed.
- **Extend `unnecessary_lambdas`-style existing rules instead of a new rule** — checked `lib/src/rules/` for an existing "redundant callback"/"unnecessary lambda" rule targeting `Future.then` specifically; none found, so a new rule is warranted rather than extending an unrelated general-purpose lambda rule (Future-specific detection needs to reason about the Future API, not just "lambda returns its argument" in general, since that same identity-lambda shape is legitimate in other contexts like `List.map`).

---

## Decision

---

## Implementation Notes

---

## Commits
