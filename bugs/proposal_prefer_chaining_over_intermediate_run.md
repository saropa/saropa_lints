# PROPOSAL: Flag `.run()` Followed Immediately by Re-Wrapping — Chain the `Task`/`TaskEither` Instead

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_chain_either`, `prefer_task_either_over_try_catch`

**Package dependency:** `fpdart`. This rule only applies to projects using `package:fpdart` and should only run when fpdart is a declared dependency.

---

## Summary

Add `prefer_chaining_over_intermediate_run` to flag code that calls `.run()` on a `Task`/`TaskEither` to eagerly materialize a `Future`, only to immediately `await` it and feed the result into another `Task`/`TaskEither`-returning operation — instead of chaining the two lazily with `.flatMap`/`.map` before ever calling `.run()`.

**Closes gap:** many_lints `prefer_chaining_over_intermediate_run` (fpdart family). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` Gap Theme 1.

---

## Motivation

`Task`/`TaskEither` are lazy — nothing runs until `.run()` is called. Calling `.run()` early just to `await` the result and pass it into another `Task`-returning call forces eager evaluation partway through what should be a single lazy pipeline, loses the ability to compose error handling across the whole chain, and reintroduces manual `try`/`catch`/`await` bookkeeping that `TaskEither` exists to avoid.

---

## Detection / Behavior

### Should flag (bad code)

```dart
Future<int> fetchAndDouble(TaskEither<String, int> fetch) async {
  final either = await fetch.run(); // LINT — intermediate .run() before chaining
  return either.getOrElse((_) => 0) * 2;
}
```

### Should pass (good code)

```dart
TaskEither<String, int> fetchAndDouble(TaskEither<String, int> fetch) {
  return fetch.map((value) => value * 2); // OK — chained lazily, run() deferred to the caller
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: fpdart-specific composition idiom, part of the same family as the other `Task`/`Either` chaining rules.

---

## Edge Cases

1. **`.run()` at the true edge of the application (e.g. inside a Bloc event handler or a top-level `main()`)** — should pass; running the `Task` is required somewhere, and the rule should only flag `.run()` followed by feeding the result back into another fpdart-typed operation, not a genuine terminal consumption.
2. **`.run()` result immediately passed to a non-fpdart function (e.g. `setState`, logging)** — should pass; there is no fpdart chain to preserve once the boundary is crossed.
3. **Multiple sequential `.run()` calls with no data dependency between them** — should pass; the rule targets the "unwrap to feed the next fpdart step" shape specifically, not any two `.run()` calls in the same function.

---

## Alternatives Considered

- **Flag every `.run()` call not at the outermost scope** — rejected as too broad; would produce false positives on genuinely necessary intermediate awaits (e.g. cancellation checks between two independent tasks).

---

## Decision

---

## Implementation Notes

---

## Commits
