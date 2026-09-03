# PROPOSAL: Flag `Future<Outcome<T>>` Return Types in Favor of a Single Async-Result Wrapper

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `no_futures`

---

## Summary

Add `no_future_outcome_type` to flag function/method signatures that return `Future<Outcome<T>>` (or any configured Result/Either-style wrapper nested inside `Future`), where the project's error-handling convention provides a dedicated async-result type (e.g. `AsyncOutcome<T>`/`TaskEither<L, R>`) that collapses both layers into one.

**Closes gap:** `df_safer_dart_lints` `no_future_outcome_type` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Stacking `Future` and a Result-style wrapper forces every caller to `await` first and then unwrap the result in a second step, and it's easy to forget one of the two failure channels — an unhandled `Future` rejection alongside a handled `Outcome.failure`. A single async-result type keeps error handling in one place and one `await` away, matching the "one obvious way to fail" discipline that `df_safer_dart_lints` is built around.

---

## Detection / Behavior

### Should flag (bad code)

```dart
Future<Outcome<User>> fetchUser(String id) async { // LINT — nested Future<Outcome<T>>, two failure channels
  try {
    final user = await api.getUser(id);
    return Outcome.success(user);
  } catch (e) {
    return Outcome.failure(e);
  }
}
```

### Should pass (good code)

```dart
AsyncOutcome<User> fetchUser(String id) { // OK — single async-result type, one failure channel
  return AsyncOutcome.guard(() => api.getUser(id));
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: requires the project to have adopted an Outcome/Result-based error-handling convention with a matching async wrapper type; not applicable to codebases using plain `try`/`catch`, so it belongs in an opt-in tier.

---

## Edge Cases

1. **`Future<Outcome<T>>` appearing only as a local variable type, not a function return type** — needs discussion; the same double-wrapping risk applies, but the signature-level case is the primary target.
2. **The project has not configured an async-result replacement type** — should not flag; the rule needs a configured target type to suggest, otherwise it has nothing constructive to recommend.
3. **`FutureOr<Outcome<T>>`** — should flag under the same rationale; still forces two-step unwrapping when the sync branch also returns a wrapped `Outcome`.
4. **Generic function that is itself generic over the wrapper type (framework/library code)** — should pass; the rule targets concrete `Future<Outcome<T>>` usage, not generic type parameters that happen to be instantiated that way by callers.

---

## Alternatives Considered

- **Ban `Outcome`/Result wrappers inside `Future` universally without requiring project configuration** — rejected; teams not using an async-result convention have no fix to apply, so the rule would be pure noise without a configured target type.

---

## Decision

---

## Implementation Notes

---

## Commits
