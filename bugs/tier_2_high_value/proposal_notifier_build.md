# PROPOSAL: Flag Riverpod Notifier `build()` Methods Called or Overridden Incorrectly

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `notifier_extends`

---

## Summary

Add `notifier_build` to flag two Riverpod `Notifier`/`AsyncNotifier` misuses of the `build()` lifecycle method: (1) manually calling `build()` from application code instead of letting Riverpod invoke it, and (2) mutating `state` from inside `build()` itself rather than returning the initial value, both of which break Riverpod's contract that `build()` is a pure "compute the initial/rebuilt state" function.

**Closes gap:** `many_lints` `notifier_build` (Riverpod-focused; pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`build()` is Riverpod's designated hook for producing a notifier's state — the framework calls it once on first read and again on every dependency invalidation, and it expects the return value to *be* the new state, not a side effect target. Calling it manually re-runs initialization logic outside the framework's tracked dependency graph, and assigning to `state` inside `build()` fights the return-value contract and can produce a state update the framework doesn't expect during its own construction pass.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class CounterNotifier extends Notifier<int> {
  @override
  int build() {
    state = 0; // LINT — assigning to `state` inside build(); return the value instead
    return state;
  }

  void resetViaBuild() {
    build(); // LINT — build() called manually; only Riverpod should invoke this
  }
}
```

### Should pass (good code)

```dart
class CounterNotifier extends Notifier<int> {
  @override
  int build() => 0; // OK — build() returns the initial state, no manual state assignment

  void reset() {
    state = 0; // OK — state mutated through the normal setter outside build()
  }
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: package-specific to Riverpod's `Notifier`/`AsyncNotifier` API; requires the `riverpod`/`flutter_riverpod` dependency.

---

## Edge Cases

1. **`state` read (not assigned) inside `build()`** — should pass; reading is fine, only assignment inside `build()` is the hazard.
2. **`ref.watch(...)` used inside `build()` to derive the return value** — should pass; this is the standard, encouraged pattern.
3. **`build()` called from within a test using Riverpod's own testing harness (`container.read(provider.notifier).build()` equivalents)** — needs discussion; test-only manual invocation may be a legitimate exception.
4. **`AsyncNotifier.build()` returning a `Future` that internally sets `state = AsyncLoading()` before awaiting** — needs discussion; some documented Riverpod patterns intentionally set loading state mid-`build()`.

---

## Alternatives Considered

- **Only flag manual `build()` calls, not in-`build()` state assignment** — rejected; both misuses stem from the same misunderstanding of `build()`'s contract and are equally worth catching together under one rule name matching upstream.

---

## Decision

---

## Implementation Notes

---

## Commits
