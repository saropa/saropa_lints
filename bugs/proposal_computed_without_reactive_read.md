# PROPOSAL: Flag `computed` Derivations That Bypass the Reactive Read Path

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_set_state_in_computed`, `avoid_worker_creation_in_computed` (both `all_observer_lint` companion proposals, being drafted in parallel batches — this rule, `avoid_set_state_in_computed`, and `avoid_worker_creation_in_computed` together form the `computed`-callback rule family for the `all_observer` reactive-state library)

---

## Summary

Add `computed_without_reactive_read` to flag a `computed`/derived-value getter in the `all_observer` reactive-state library that reads an observable's underlying value WITHOUT going through the library's tracked-read mechanism — e.g. reaching past `.value` into a raw/untracked accessor, or capturing a snapshot of the observable before entering the reactive tracking context — so the computed's dependency graph never registers that read and the derived value silently goes stale.

**Closes gap:** `all_observer_lint` `computed_without_reactive_read` (github.com/CriandoGames/all_observer_lint). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` `all_observer_lint` section (HAVE: 0, PARTIAL: 0, GAP: 20 — saropa has zero coverage of this library today).

---

## Motivation

A `Computed` value's entire correctness contract rests on the framework being able to observe every read that happens during its evaluation, so it knows exactly which upstream `Observable`s to re-subscribe to. That tracking is implicit — it happens automatically when a read goes through the library's designed accessor path (typically `.value` on an `Observable`/`Computed` instance evaluated synchronously inside the `computed` callback) — but it is trivially broken by innocuous-looking refactors: capturing `final snapshot = observable.value;` one line above the tracked region and then reading `snapshot` inside the callback, or exposing a "peek"/untracked accessor for debugging that a developer reaches for out of habit. The failure mode is the worst kind for a reactive system: no exception, no warning, just a `computed` value that silently freezes at whatever it happened to evaluate to the first time, while the rest of the UI continues believing it is reactive.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class ProfileViewModel {
  final Observable<String> name = Observable('Alice');

  // Snapshot taken outside the tracked evaluation — the read of `name.value`
  // happens on the line above, not inside the `Computed(() => ...)` callback,
  // so the dependency graph never links `greeting` to `name`.
  final String _snapshot = '';

  late final Computed<String> greeting = Computed(() {
    return 'Hello, $_snapshot!'; // LINT — reads a value captured outside the
                                  // reactive tracking context; not a tracked read
  });

  late final Computed<String> greetingUntracked = Computed(() {
    return 'Hello, ${name.peek()}!'; // LINT — `.peek()`/untracked accessor
                                      // deliberately bypasses dependency tracking
  });
}
```

### Should pass (good code)

```dart
class ProfileViewModel {
  final Observable<String> name = Observable('Alice');

  // `.value` read happens directly inside the Computed callback, so the
  // framework's tracking context registers `name` as a dependency.
  late final Computed<String> greeting = Computed(() {
    return 'Hello, ${name.value}!'; // OK — tracked reactive read
  });
}
```

---

## Proposed Tier

Tier: Comprehensive (or Pedantic)
Justification: This rule only fires on projects depending on the niche `all_observer` reactive-state library — most saropa_lints consumers use GetX, Riverpod, Bloc, Provider, or plain `setState` and would never see this rule trigger. Library-specific rules with a narrow install base belong in Comprehensive/Pedantic, matching the tier recommended for the companion rules `avoid_set_state_in_computed` and `avoid_worker_creation_in_computed` in this same family, and matching saropa's existing placement for other niche package-specific checks.

---

## Edge Cases

1. **`.value` read directly inside the `Computed(() => ...)` callback body** — should pass; this is the canonical tracked-read pattern.
2. **`.value` read assigned to a local variable inside the callback, then that local used later in the same callback** (`final v = observable.value; return v * 2;`) — should pass; the read still occurs inside the tracked evaluation context even though it's not inline at the return statement.
3. **`.value` read captured in a field or local declared BEFORE/OUTSIDE the `Computed` callback, then referenced inside it** — should flag; the read already happened outside the tracking window by the time the callback runs, per the first bad example.
4. **An explicit untracked/`peek()`-style accessor called inside the callback** — should flag; the library exposes this specifically to bypass tracking, which is antithetical to a `computed` derivation's purpose.
5. **Reading a plain (non-observable) local variable or a non-reactive field inside the callback** — should pass; the rule only targets reads of `Observable`/`Computed`-typed state, not ordinary Dart values.
6. **Nested closures inside the `computed` callback** (e.g. a read inside a `.map()` lambda passed to a list derived within the computed) — should still flag/pass based on whether the read reaches the reactive accessor, same logic as the outer callback, since the nested closure still executes inside the tracked evaluation window when called synchronously.

---

## Alternatives Considered

- **Flag any use of a "snapshot" local variable pattern generally, independent of the reactive library** — rejected; without resolving the `all_observer` `Observable`/`Computed` types specifically, this degenerates into a broad "don't cache a value before using it" rule with far higher false-positive risk across ordinary, non-reactive Dart code.
- **Only flag the explicit `peek()`/untracked-accessor case, skip the harder "value captured outside the callback" detection** — considered as a smaller, higher-precision first cut, but rejected because the gap analysis names `computed_without_reactive_read` specifically (not a narrower `peek`-only variant), and the outside-capture case is likely the more common real-world bug source since it looks like ordinary refactoring rather than a deliberate escape hatch.

---

## Decision

---

## Implementation Notes

Package-specific — targets the `all_observer` reactive-state library's `Observable`/`Computed` API. No existing rule file covers this library; a grep of `lib/src/rules/packages/` finds no `all_observer_rules.dart`, `mobx_rules.dart`, or `signals_rules.dart`. This rule should live alongside `avoid_set_state_in_computed` and `avoid_worker_creation_in_computed` in a new `lib/src/rules/packages/all_observer_rules.dart` file, sharing that file's `Computed(...)` callback-detection helper (identifying the closure argument passed to a `Computed` constructor/factory) so all three sibling rules walk the same AST region consistently. Detection requires distinguishing reads that occur lexically/temporally inside the `Computed` callback's body from reads that occur in the enclosing scope before the callback is constructed — likely via tracking whether the read expression's nearest enclosing `FunctionExpression` is the `Computed` argument itself. Add the standard `ProjectContext` dependency check (skip scanning when the target project doesn't depend on `all_observer`) as established by other package-specific rule files.

---

## Commits
