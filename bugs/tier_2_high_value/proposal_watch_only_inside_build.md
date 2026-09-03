# PROPOSAL: Flag `Observer`/`watch()` Subscribing to More State Than `build()` Reads

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `unobserved_reactive_read_in_build` (proposed), `unused_reactive_state` (proposed)

---

## Summary

Add `watch_only_inside_build` for the `all_observer` package: flag an `Observer(builder: ...)` (or equivalent tracking scope) whose `build`-equivalent closure reads only a subset of the `Observable`s captured in its enclosing scope, when a narrower `Observer` around just the read values would avoid over-broad rebuilds — the inverse problem of `unobserved_reactive_read_in_build`.

**Closes gap:** `all_observer_lint` `watch_only_inside_build`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "all_observer_lint" section (0/20 coverage).

---

## Motivation

saropa already enforces the equivalent "watch only what you need" discipline for Riverpod (`prefer_ref_watch_over_read`, `prefer_riverpod_select`) and Provider (`prefer_context_selector`) — over-broad subscriptions cause unnecessary widget rebuilds whenever ANY tracked value changes, not just the one the widget actually displays. `all_observer`'s `Observer` widget has the identical performance trap and, per `GAP_ANALYSIS.md`, zero saropa coverage of the package exists today.

---

## Detection / Behavior

Flag an `Observer(builder: (context) { ... })` closure that reads a computed/derived value which itself only depends on a subset of `Observable`s in a larger aggregate object, where a `Computed` selecting just that subset (and observing the `Computed` instead of the aggregate) would narrow the rebuild scope. In the simplest, high-confidence form: flag when the `Observer`'s builder reads `.value` on an `Observable<SomeLargeObject>` and only accesses one field of the resulting object.

### Should flag (bad code)

```dart
Observer(
  builder: (context) {
    final settings = appSettings.value; // LINT — subscribes to the whole object
    return Text(settings.displayName);   // but only ever reads one field
  },
);
```

### Should pass (good code)

```dart
final displayName = Computed(() => appSettings.value.displayName);

Observer(
  builder: (context) => Text(displayName.value), // OK — narrowly scoped subscription
);
```

---

## Proposed Tier

Tier: Pedantic
Justification: Package-specific performance-style rule with real false-positive risk (single-field access today doesn't guarantee no other fields will be read as the widget evolves) — needs to start opt-in.

---

## Edge Cases

1. **`Observer` builder reads multiple fields of the same aggregate `Observable`** — should pass; narrowing to per-field `Computed`s only pays off when just one field is used, otherwise the aggregate subscription is already efficient.
2. **`Observable<PrimitiveType>` (already narrow, e.g. `Observable<bool>`)** — should pass; nothing to narrow further.
3. **`all_observer` package not a project dependency** — rule should no-op entirely.
4. **Field access used only for a conditional that doesn't affect the rendered output (e.g. a debug-only branch)** — should still flag under the same detection heuristic; distinguishing "affects rendering" from "doesn't" is out of scope for a static single-pass rule.

---

## Alternatives Considered

- **Skip this rule and rely on `unobserved_reactive_read_in_build` alone** — rejected; the two rules cover opposite failure directions (under-subscribing causes stale UI, over-subscribing causes wasted rebuilds) and both are named separately upstream, so parity requires both.

---

## Decision

---

## Implementation Notes

---

## Commits
