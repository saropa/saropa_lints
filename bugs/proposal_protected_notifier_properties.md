# PROPOSAL: Flag Public Mutable State Fields on Riverpod Notifier Classes

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: avoid_public_notifier_properties (many_lints name for the same concept — none: does not yet exist in saropa_lints; cross-reference if implemented)

---

## Summary

Add `protected_notifier_properties` to flag a public (non-`_`-prefixed) mutable field declared directly on a class extending Riverpod's `Notifier`, `AsyncNotifier`, or the legacy `StateNotifier`, when that field is accessed or reassigned from outside the notifier class. Riverpod's contract is that external code reads state via `ref.watch(provider)` and mutates it only through the notifier's own public methods — a directly-mutable public field bypasses both the notifier's invariants and Riverpod's rebuild/listener notification pipeline.

**Closes gap:** riverpod_lint (github.com/rrousselGit/riverpod), also present as `avoid_public_notifier_properties` in many_lints. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`, Riverpod lifecycle/naming completeness theme.

---

## Motivation

A Riverpod `Notifier<T>`/`AsyncNotifier<T>` is meant to own its state exclusively: the framework tracks mutations through `state = newValue` (or the notifier's own setter machinery) to trigger listener notifications and rebuilds. If a notifier exposes an additional public mutable field beyond `state` — say, a `List<Item> cachedItems` that a widget mutates directly with `notifier.cachedItems.add(item)` — that mutation happens completely outside Riverpod's notification pipeline: dependent widgets never rebuild, `ref.listen` callbacks never fire, and the notifier's own invariants (validation, derived-field recomputation) are silently skipped. This is a specific instance of the "keep mutable state private, expose only through owner-controlled methods" encapsulation principle, applied to the Notifier lifecycle contract specifically — it depends on the `riverpod`/`flutter_riverpod` package's `Notifier`/`AsyncNotifier`/`StateNotifier` base classes.

---

## Detection / Behavior

Flag a field declared on a class extending `Notifier<T>`, `AsyncNotifier<T>`, or `StateNotifier<T>` that is (a) public (no `_` prefix), (b) mutable (not `final`, and not a getter-only computed property), and (c) referenced or assigned from a location outside the declaring notifier class (i.e. from a widget, another provider, or any external call site) — either as a read that is then mutated in place (`.add()`, `[]=`, etc. on a public mutable collection field) or a direct reassignment (`notifierInstance.field = ...`).

### Should flag (bad code)

```dart
class CartNotifier extends Notifier<List<Item>> {
  @override
  List<Item> build() => [];

  List<Item> pendingRemovals = []; // LINT — public mutable field on a Notifier, accessed externally below
}

void removeFromCartOutside(CartNotifier notifier, Item item) {
  notifier.pendingRemovals.add(item); // bypasses Riverpod's state pipeline entirely
}
```

### Should pass (good code)

```dart
class CartNotifier extends Notifier<List<Item>> {
  @override
  List<Item> build() => [];

  final List<Item> _pendingRemovals = []; // OK — private, no external mutation surface

  void markForRemoval(Item item) {
    _pendingRemovals.add(item); // OK — mutated only through the notifier's own method
    state = [...state]..remove(item); // OK — goes through Riverpod's `state` setter
  }
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Depends on the `riverpod`/`flutter_riverpod` package's `Notifier`/`AsyncNotifier`/`StateNotifier` base classes — irrelevant to any project not using Riverpod for state management. Niche/opt-in per project's state-management choice, not appropriate for Essential/Recommended.

---

## Edge Cases

1. **Public `final` immutable field or getter-only computed property on a Notifier** — should pass; immutability removes the bypass risk since there is nothing to mutate through the field.
2. **Public mutable field accessed only from within the same notifier class** — should pass; the rule's concern is external bypass of the state pipeline, not internal field usage. (A stricter variant could still flag any public mutable field regardless of external access, trading precision for simplicity — noted as an implementation choice, not the proposed default.)
3. **The framework-mandated `state` field/getter itself** — must never flag; `state` is the intended, framework-blessed external-facing property and is exactly the mechanism this rule wants developers to use instead of ad hoc public fields.
4. **A public method that internally mutates a private field and is the sole external mutation path** — should pass; this is the correct pattern the rule wants to encourage.
5. **Legacy `StateNotifier<T>` from the `state_notifier` package (pre-Riverpod-2 API) with a public mutable field** — should still flag; the same bypass risk applies regardless of which generation of the API is in use.

---

## Alternatives Considered

- **Flag every public mutable field on a Notifier regardless of observed external access** — rejected as the default because it produces false positives on fields that are public only for testing convenience but never actually mutated outside the class in production code paths; the proposal's external-access condition keeps the rule precise, though a simpler "any public mutable field" variant remains available as a stricter opt-in if cross-file access tracking proves unreliable.
- **Rename to match many_lints' `avoid_public_notifier_properties`** — considered for naming consistency with the more widely-known many_lints package, but the source-of-truth cited in the gap analysis is riverpod_lint's `protected_notifier_properties`; keep this name and cross-reference the many_lints alias in `Related rules` so either search term finds the rule.

---

## Decision

---

## Implementation Notes

Needs cross-file usage tracking (is this field ever accessed from outside the declaring class?) — check `lib/src/` for existing cross-file reference-tracking utilities (used by e.g. unused-member detection) before building new infrastructure for this.

---

## Commits
