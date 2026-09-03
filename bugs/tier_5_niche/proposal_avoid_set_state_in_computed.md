# PROPOSAL: Flag State Mutation Inside a Reactive `computed` Derivation

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `avoid_set_state_in_computed` to flag a call that mutates observable/reactive state (`setState`, a reactive-store setter, or an equivalent write) from inside a `computed`/derived-value callback in a reactive-state-observer library. A `computed` getter is meant to be a pure, side-effect-free derivation of existing state — writing to state during its own evaluation creates a feedback loop the reactive graph cannot resolve deterministically.

**Closes gap:** `all_observer_lint` `avoid_reactive_write_in_computed` / `avoid_set_state_in_computed` (github.com/CriandoGames/all_observer_lint). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` `all_observer_lint` section (HAVE: 0, PARTIAL: 0, GAP: 20 — saropa has zero coverage of this library today).

---

## Motivation

Reactive/observer libraries (MobX-style `Observable`/`Computed`/`Observer`, Riverpod-style derived providers, or the niche `all_observer` package this gap targets) rely on `computed` values being pure functions of other observable state: the framework re-runs the derivation whenever an upstream dependency changes and caches the result until the next change. Writing to observable state from inside that derivation either (a) triggers another re-evaluation of the same computed value mid-evaluation (infinite loop / stack overflow risk), or (b) silently desyncs the reactive graph so downstream observers see a stale or inconsistent value depending on evaluation order. Because the mutation and the read live in the same call stack, this bug class rarely throws a clear error — it manifests as "the UI updates twice" or "state occasionally doesn't converge," which is expensive to root-cause without a static check flagging the pattern at the source.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class CartViewModel {
  final Observable<List<Item>> items = Observable(<Item>[]);
  final Observable<double> _lastTotal = Observable(0);

  late final Computed<double> total = Computed(() {
    final double sum = items.value.fold(0, (double acc, Item i) => acc + i.price);
    _lastTotal.value = sum; // LINT — writing to observable state inside a computed derivation
    return sum;
  });
}
```

### Should pass (good code)

```dart
class CartViewModel {
  final Observable<List<Item>> items = Observable(<Item>[]);

  // Pure derivation — reads observable state, writes nothing.
  late final Computed<double> total = Computed(() {
    return items.value.fold(0, (double acc, Item i) => acc + i.price); // OK
  });

  // Side effects that need to write state belong in an effect/action, not a computed.
  void recordLastTotal() {
    _lastTotal.value = total.value; // OK — outside the computed callback
  }
}
```

---

## Proposed Tier

Tier: Comprehensive (or Pedantic)
Justification: This rule only fires on projects using a specific reactive/observer library — most saropa_lints consumers (GetX, Riverpod-standard-usage, Bloc, Provider, plain `setState`) will never trigger it. Library-specific rules with a narrow install base belong in Comprehensive/Pedantic, matching how saropa already tiers other niche package-specific checks (e.g. `qr_scanner_rules.dart`, `audioplayers_rules.dart`), not Essential/Recommended where broad applicability is the bar.

---

## Edge Cases

1. **`setState()` (Flutter's `State.setState`) called inside a `computed` getter** — should flag; `setState` is itself a synchronous rebuild trigger and is even more dangerous mid-derivation than a plain observable write.
2. **Reading (not writing) other observable/computed values inside the derivation** — should pass; reads are the entire point of a computed value.
3. **Write to a plain local variable or a non-observable field inside the computed callback** — should pass; the rule targets writes to reactive/observable state specifically, not general mutation.
4. **Write inside a nested closure passed to `Future`/`Timer`/an async callback from within the computed body** — should flag; the write still originates from code defined inside the computed derivation and the same feedback-loop risk applies once the callback fires, even though it's deferred.
5. **Write inside an `action`/`runInAction`-wrapped block nested inside the computed callback** — needs discussion; some observer libraries explicitly permit action-wrapped writes as an escape hatch. Default to flagging (the escape hatch is itself a design smell inside a computed) but note this as a likely source of false positives if the target library supports it.

---

## Alternatives Considered

- **Detect purely by naming convention** (any field/getter assigned via a `Computed(...)` or annotated with a `@computed`-style marker, without resolving the actual library type) — likely necessary in practice since `usesTypeResolution` may not reliably identify a niche/unpublished-widely package's exact API surface; call out in Implementation Notes as the fallback detection strategy if type-based resolution proves too narrow.
- **General-purpose "no side effects in getters" rule** (not library-specific) — rejected as the initial scope; a blanket "don't mutate state in a getter" rule would have far higher false-positive risk across ordinary Dart code (e.g. lazy-init caching patterns) and loses the specific, well-understood semantics that make this gap concrete for the `all_observer` library the gap analysis names.

---

## Decision

---

## Implementation Notes

Package-specific — `saropa_lints` has no existing rule file targeting `all_observer`, MobX, or Signals-style reactive libraries; a grep of `lib/src/rules/packages/` turns up no `mobx_rules.dart`, `signals_rules.dart`, or `all_observer_rules.dart`. This would be the first rule in a new `lib/src/rules/packages/all_observer_rules.dart` (or a more general `reactive_state_rules.dart` if the intent is to eventually support MobX too) and needs a corresponding entry in `pubspec.yaml` awareness (detecting whether the target project even depends on the library, to avoid dead-weight scanning on projects that don't use it) — check `ProjectContext` for the existing dependency-detection pattern used by other package-specific rule files before implementing.

---

## Commits
