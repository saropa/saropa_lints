# PROPOSAL: Flag Public Fields on Riverpod Notifier Classes

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_ref_watch_outside_build`, `avoid_ref_read_inside_build`

---

## Summary

Flag public (non-underscore-prefixed) instance fields declared on a Riverpod `Notifier`/`AsyncNotifier` subclass, since consumers should read state exclusively through the provider's `state`, not through ad hoc public fields on the notifier instance.

**Closes gap:** DCM `avoid-public-notifier-properties` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

Riverpod's contract is that a `Notifier` exposes state through the framework-managed `state` field (and the provider that wraps it), and exposes behavior through methods. A public field on the notifier bypasses that contract: it isn't watched, doesn't trigger rebuilds when mutated, and gives external callers a second, unmanaged channel into notifier internals that Riverpod's dependency graph can't track. This produces the same class of "stale UI" bug that `avoid_ref_read_inside_build` catches for the read side, but originating from the notifier's own public surface instead of a call site. No existing saropa_lints rule enforces private-by-default fields specifically on Riverpod notifiers (confirmed by grep — zero matches for `avoid_public_notifier_properties` in `lib/src/rules/`; the general `prefer_private_fields`-style rules, if any, are not Notifier-aware).

---

## Detection / Behavior

### Should flag (bad code)

```dart
class CartNotifier extends Notifier<Cart> {
  int itemCount = 0; // LINT — public field, bypasses Riverpod's state tracking

  @override
  Cart build() => Cart.empty();

  void addItem(Item item) {
    itemCount++; // mutation invisible to widgets watching cartProvider
    state = state.copyWith(items: [...state.items, item]);
  }
}
```

```dart
class SessionNotifier extends AsyncNotifier<Session?> {
  DateTime lastRefreshed = DateTime.now(); // LINT — public mutable field

  @override
  Future<Session?> build() async => null;
}
```

### Should pass (good code)

```dart
class CartNotifier extends Notifier<Cart> {
  int _itemCount = 0; // OK — private, internal bookkeeping only

  @override
  Cart build() => Cart.empty();

  void addItem(Item item) {
    _itemCount++;
    state = state.copyWith(items: [...state.items, item]);
  }
}
```

```dart
class SessionNotifier extends AsyncNotifier<Session?> {
  static const Duration refreshInterval = Duration(minutes: 5); // OK — static const, not instance state

  @override
  Future<Session?> build() async => null;
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Encapsulation convention specific to the Riverpod `Notifier` pattern — meaningful for teams standardizing on Riverpod's state-management contract, but not a universal correctness rule that belongs in Essential/Recommended. Matches the tier of the sibling Riverpod naming/structure proposals.

---

## Edge Cases

1. **`static` fields (including `static const`)** — should pass; static members are not per-instance state and are commonly used for constants (e.g. debounce durations, provider-scoped config).
2. **`final` public fields set only via constructor (dependency injection style)** — needs discussion; DCM's rule targets general public properties, but a `final` field assigned once in the constructor and never reassigned is arguably closer to configuration than mutable state. Initial implementation should still flag it (consistent, simple rule) with a documented rationale; teams needing DI-style notifiers can inject via `ref.read` of another provider instead.
3. **Fields with `@visibleForTesting`** — should pass; the annotation is an explicit signal the field is intentionally exposed for test harnesses, matching the pattern used elsewhere in the codebase for test-visibility exceptions.
4. **Getters that merely compute from `state` (no backing field)** — should pass; a public getter derived from `state` is the correct read-only pattern and is not itself a stored property.
5. **Public fields on a plain data class annotated `@riverpod` via code generation, not on the Notifier class itself** — should pass; the rule targets the `Notifier`/`AsyncNotifier` subclass declaration only, not the state model it wraps.

---

## Alternatives Considered

- **Extend a hypothetical general `prefer_private_fields` rule with Riverpod awareness** — rejected; saropa_lints keeps package-specific conventions in dedicated package rule files (`lib/src/rules/packages/riverpod_rules.dart`), matching the existing separation between general Dart rules and Riverpod-specific ones (`avoid_ref_read_inside_build`, `avoid_ref_watch_outside_build`).
- **Only flag mutable (non-final) public fields** — considered as a narrower first cut to reduce noise on constructor-injected `final` fields, but rejected in favor of matching DCM's blanket "public property" scope for full gap closure; edge case #2 documents the trade-off.
