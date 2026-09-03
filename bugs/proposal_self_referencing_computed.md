# PROPOSAL: Flag a `Computed` Whose Compute Callback Reads Its Own `.value`

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none — saropa currently has ZERO rules for all_observer_lint (a fully unrecognized niche package); this proposal is a first foothold in that package's rule surface, not part of a completeness push.

---

## Summary

Add `self_referencing_computed` to flag a `Computed<T>` reactive value whose compute callback reads its OWN `Computed` variable's `.value` — a self-referential read that cannot resolve, since a computed value's definition cannot depend on its own not-yet-computed result. Depending on the library's evaluation order this either throws, deadlocks, or silently produces stale/undefined behavior; either way it is always a bug, never an intentional pattern.

**Closes gap:** all_observer_lint `self_referencing_computed` (github.com/CriandoGames/all_observer_lint). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` section 13 (all_observer_lint, 20-rule unrecognized-package gap group).

---

## Motivation

**Package dependency note:** this rule targets `all_observer_lint`'s host package — a niche reactive-state library (`Observable`/`Computed`/`Observer`/`effect`/`batch` API, similar in spirit to MobX or Signals). It has no meaning in projects not using this library's `Computed` API.

A `Computed<T>` value is defined as a pure derivation from other reactive `Observable`s — its compute function is re-run whenever an upstream dependency changes, and its own `.value` is the memoized result of that computation. Reading the `Computed`'s own `.value` from inside its own compute callback is a logical impossibility: at the moment the callback runs, the value being computed does not exist yet, so there is nothing for the self-read to return. Depending on the library's internal evaluation strategy this manifests as: a thrown "circular dependency" error, an infinite recomputation loop (deadlock), or — worst case — a silently stale cached value from a PREVIOUS computation being returned, which is indistinguishable from a working computed value until the bug causes a hard-to-trace downstream inconsistency. This is unambiguously always a bug; there is no legitimate use case for a computed value depending on itself, unlike some circular-reference patterns that have valid escape hatches elsewhere.

Saropa currently has no rules recognizing this package at all (a themed 20-rule gap in `plans/GAP_ANALYSIS.md` section 13); this proposal targets the single highest-value rule from that group — a guaranteed-bug detector, not a style preference — as a first foothold rather than attempting completeness across all 20.

---

## Detection / Behavior

Flag a variable declaration of the form `final someVar = Computed(() { ... });` (or `Computed<T>(...)`) where the compute callback body contains a read of `someVar.value` — i.e. the callback closes over and reads the `.value` property of the very `Computed` instance being constructed/assigned.

### Should flag (bad code)

```dart
final counter = Observable(0);

// LINT — doubled reads its OWN .value inside its own compute callback;
// there is no prior value for the self-read to resolve to.
final doubled = Computed(() => counter.value * 2 + doubled.value);
```

### Should pass (good code)

```dart
final counter = Observable(0);

// OK — derives purely from `counter`, an independent Observable.
final doubled = Computed(() => counter.value * 2);

// OK — a second Computed may read a DIFFERENT Computed's value; only
// reading one's own value inside its own callback is the bug.
final doubledPlusTen = Computed(() => doubled.value + 10);
```

---

## Proposed Tier

Tier: Pedantic
Justification: This is a first-foothold rule for a fully unrecognized niche package with a small user base relative to Riverpod/Bloc/Provider. Even though the bug it catches is unambiguous and always wrong, the audience is narrow enough that Pedantic (opt-in, low-priority) is the appropriate placement rather than a broadly-enabled tier — matches saropa's existing placement pattern for other single-package niche-library rules.

---

## Edge Cases

1. **Indirect self-reference through an intermediate variable** (`final self = doubled; final doubled = Computed(() => self.value);` — order-dependent and likely a compile error in Dart due to definite-assignment rules for `final`, since `self` would reference `doubled` before it's initialized) — Dart's own compiler already prevents most of these via "local variable used before it's definitely assigned" errors; the rule should focus on the syntactically direct self-reference case that DOES compile (the callback closure captures `doubled` lazily, so Dart allows the reference even though it resolves to a not-yet-fully-initialized `late`/self-referential binding at the point the callback first runs).
2. **A `Computed` reading a DIFFERENT `Computed`'s `.value`, including a chain that eventually cycles back** (`a` reads `b`, `b` reads `a`) — true multi-hop circular dependency detection is a much harder graph problem; scope this initial rule to the direct single-hop self-reference only (matching the upstream rule's name, `self_referencing_computed`, not `circular_computed_chain`). Note multi-hop cycle detection as a distinct, harder follow-up rule, out of scope here.
3. **`Computed` constructed with a named/library-prefixed import** (`obs.Computed(...)`) — should still flag; match on the constructor's resolved type, not the bare identifier text.
4. **A `Computed` used inside `batch()` or `effect()` blocks unrelated to its own definition** — should pass; the rule only inspects the compute callback passed to the `Computed` constructor itself, not unrelated call sites elsewhere that legitimately read the `Computed`'s value after construction.

---

## Alternatives Considered

- **Ship all 20 all_observer_lint rules in this proposal batch** — rejected; GAP_ANALYSIS groups these as a themed 20-rule set for a niche package, but each targets a distinct API surface (`Observer`, `effect`, `batch`, etc.) with its own AST pattern. Landing the single highest-confidence, always-a-bug rule first establishes the package foothold without committing to reviewing 20 rules' worth of AST logic in one pass.
- **Full multi-hop circular-dependency graph analysis** (detecting `a` -> `b` -> `a` chains, not just direct self-reference) — rejected for this proposal's scope; matches the upstream rule's stated single-hop concept, and multi-hop cycle detection needs cross-declaration graph construction that is a meaningfully larger implementation effort, better proposed as its own follow-up rule if there is demand.

---

## Decision

---

## Implementation Notes

---

## Commits
