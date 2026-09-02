# PROPOSAL: Flag Async Operations Inside an `all_observer` `batch()` Call

**Status: Open**

Created: 2026-09-02
Type: New rule (package-specific — depends on the `all_observer` reactive-state package)
Related rules: `avoid_effect_creation_in_build` (companion `all_observer` proposal)

---

## Summary

Add `async_inside_batch` to flag `await`, `Future`, or `async`-callback usage written directly inside an
`all_observer` `batch(() { ... })` call. `batch()` exists to synchronously coalesce multiple reactive writes
into a single notification; putting async work inside it defeats that guarantee, since the batch closes
before the awaited work resumes and any writes after the `await` fire outside the intended batch.

**Closes gap:** `all_observer_lint` `async_inside_batch` (github.com/CriandoGames/all_observer_lint).
Implementing this proposal as specified fully closes this competitive gap for projects using the
`all_observer` package — see `plans/GAP_ANALYSIS.md` "all_observer_lint" section (20/20 GAP).

---

## Motivation

`all_observer` is a MobX/Signals-style reactive-state library where `batch()` is a performance and
correctness primitive: it defers observer notifications until the synchronous callback completes, so
multiple related writes produce one re-render instead of several. An `await` inside that callback silently
breaks the batching contract — code after the `await` runs after `batch()` has already returned and
notified, so those writes are no longer batched, and the bug is invisible without deep knowledge of the
library's internals. This is exactly the kind of package-specific footgun a dedicated lint exists to catch;
`all_observer_lint` is the prior art and saropa currently has zero rules recognizing the `all_observer`
package at all.

---

## Detection / Behavior

### Should flag (bad code)

```dart
void updateUser() {
  batch(() async { // LINT — async_inside_batch: async callback breaks batch() coalescing guarantee
    name.value = 'Alice';
    await fetchAge(); // work after this await is no longer inside the batch
    age.value = 30;
  });
}
```

### Should pass (good code)

```dart
Future<void> updateUser() async {
  final newAge = await fetchAge(); // OK — async work done before entering batch()
  batch(() {
    name.value = 'Alice';
    age.value = newAge;
  });
}
```

---

## Proposed Tier

Tier: Comprehensive (package-dependent — see `all_observer` dependency note)
Justification: Only fires in projects depending on `all_observer`; should be gated the same way saropa gates
other package-specific rules (Riverpod, Bloc, GetX) — inert unless the package import is present, placed in
Comprehensive since it targets a specific correctness footgun rather than a universal Dart concern.

---

## Edge Cases

1. **`batch()` callback with no async content** — should pass; the rule only fires on `await`, `async`
   keyword, or `Future`-returning calls inside the callback body.
2. **A `batch()` call nested inside an unrelated `async` function**, where the outer function is `async` but
   the `batch()` callback itself is synchronous — should pass; only the callback passed to `batch()` matters.
3. **Fire-and-forget `Future` started without `await` inside `batch()`** (`someAsyncCall();` with no
   `await`) — needs discussion; the batch itself isn't broken since nothing suspends, but the started future's
   own writes will land outside any batch — likely still worth flagging as a related but distinct pattern.
4. **Project does not depend on `all_observer`** — must not fire; gate on package presence like saropa's
   other ecosystem-specific rules.

---

## Alternatives Considered

- **Generic "no async inside batching primitives" rule** covering multiple state-management libraries with
  batch-like APIs (Riverpod's `ProviderContainer.updateShouldNotify`-adjacent patterns, etc.) — rejected for
  this proposal; scope to `all_observer`'s `batch()` specifically to match the cited gap, generalize later
  if a second library with the same shape is found.

---

## Decision

---

## Implementation Notes

---

## Commits
