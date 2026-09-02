# PROPOSAL: Flag `effect()` Callbacks With No Reactive Read

**Status: Open**

Created: 2026-09-02
Type: New rule (package-specific: `all_observer`)
Related rules: none

---

## Summary

Add `effect_without_reactive_read` to flag an `all_observer` `effect(...)` callback whose body never reads an observable/reactive value, meaning the effect has no dependency and will only ever run once (on registration) rather than reactively.

**Closes gap:** `all_observer_lint` `effect_without_reactive_read`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "all_observer" gaps section.

---

## Motivation

`effect()` re-runs automatically only when a reactive value read inside its callback changes. An `effect()` body that reads no observable (e.g. only touches plain fields or performs constant work) silently degrades to a one-shot side effect, which usually indicates the developer forgot to read the reactive source they intended to react to.

---

## Detection / Behavior

### Should flag (bad code)

```dart
void watchCount(int plainCount) {
  effect(() {
    print('Count is $plainCount'); // LINT — no reactive read inside effect(); this only runs once, never reacts to changes
  });
}
```

### Should pass (good code)

```dart
final count = Observable<int>(0);

void watchCount() {
  effect(() {
    print('Count is ${count.value}'); // OK — reads a reactive value, effect re-runs on change
  });
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: package-specific rule for `all_observer`; only relevant to projects that depend on it.

---

## Edge Cases

1. **`effect()` that reads a reactive value only inside a nested closure not directly invoked during the effect run (e.g. stored as a callback for later)** — needs discussion; static analysis can't always prove the closure runs synchronously within the effect body, so a conservative implementation may under-flag here.
2. **`effect()` whose sole purpose is a one-time side effect on mount, using `effect()` instead of a plain function by mistake** — should flag; this is exactly the bug the rule targets, even if intentional the reviewer should be prompted to use a plain callback instead.
3. **`effect()` that reads a reactive value conditionally (only inside an `if` branch that may not execute on first run)** — should pass; the read exists in the AST even if not always executed at runtime — dependency tracking evaluates per-run regardless.
4. **`effect()` reading a reactive collection via `dispose_reactive_resources`-tracked helper method that internally reads reactively** — needs discussion; cross-function reactive-read tracing is likely out of scope for a first version, flag only direct reads in the callback body.

---

## Alternatives Considered

- **Only warn, never error, since it's a legal (if usually wrong) pattern** — accepted as the default severity; this is a "probably a mistake" heuristic, not a certain bug, so default to warning severity rather than error.

---

## Decision

---

## Implementation Notes

Shares reactive-type/tracking-context detection with `copied_reactive_collection_outside_tracking` and `dispose_reactive_resources` — build a shared `all_observer` type-recognition helper once, reuse across all three.

---

## Commits
