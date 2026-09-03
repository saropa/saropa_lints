# PROPOSAL: Require `Notifier` Suffix on Notifier Subclasses

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_correct_notifier_file_name`, `prefer_single_notifier_per_file`

---

## Summary

Flag a Riverpod `Notifier`/`AsyncNotifier` subclass whose class name doesn't end in `Notifier`.

**Closes gap:** DCM `prefer-riverpod-notifier-suffix` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

Every Riverpod style guide and generated scaffold (including `riverpod_generator`) names notifier classes with a `Notifier` suffix by convention — `CartNotifier`, `SessionNotifier`. A class that extends `Notifier`/`AsyncNotifier` without the suffix (`CartManager`, `CartLogic`) reads, at a glance, like a plain service class, obscuring that it participates in Riverpod's provider graph, has `state`/`ref` semantics, and must not be instantiated directly. This is a pure naming convention rule, directly analogous to naming-suffix rules saropa already enforces elsewhere in the codebase (e.g. Bloc's event/state naming conventions in `bloc_rules.dart`), but grep confirms zero matches for `prefer_riverpod_notifier_suffix` in `lib/src/rules/` — no existing rule enforces it for Riverpod notifiers.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class CartManager extends Notifier<Cart> { // LINT — should end in "Notifier"
  @override
  Cart build() => Cart.empty();
}
```

```dart
class SessionController extends AsyncNotifier<Session?> { // LINT
  @override
  Future<Session?> build() async => null;
}
```

### Should pass (good code)

```dart
class CartNotifier extends Notifier<Cart> { // OK
  @override
  Cart build() => Cart.empty();
}
```

```dart
class SessionNotifier extends AsyncNotifier<Session?> { // OK
  @override
  Future<Session?> build() async => null;
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Naming convention with no runtime effect — matches the tier chosen for the other Riverpod naming/structure proposals in this batch. Teams adopting a house style benefit; teams that don't use Riverpod's default naming pattern (rare, but real, e.g. legacy migrations) shouldn't be forced onto it by default.

---

## Edge Cases

1. **Abstract base notifier classes meant to be extended (`abstract class BaseNotifier<T> extends Notifier<T>`)** — should discuss; an abstract intermediate class already ends in a word describing its role, not a concrete feature name — flagging `BaseNotifier` itself is a false alarm since it already carries the suffix. If the base doesn't carry the suffix (e.g. `abstract class FeatureBase<T> extends Notifier<T>`), it should still flag, since concrete subclasses inheriting from it are exactly the case this rule protects.
2. **`StateNotifier` (the older, non-Riverpod-3 API, `package:state_notifier` or legacy Riverpod)** — should flag using the same suffix rule if the class extends `StateNotifier` and doesn't end in `Notifier`; the naming convention is identical across the older and newer notifier APIs.
3. **Generic notifier factories/mixins that don't directly extend `Notifier`** — should pass; only direct or resolvable inheritance from `Notifier`/`AsyncNotifier`/`StateNotifier` triggers the check, matching how `isEquatable`-style helper checks in the codebase resolve direct extends/mixin clauses rather than doing whole-hierarchy resolution.
4. **Class name ending in `Notifier` but as a substring coincidence unrelated to the suffix (e.g. `NotifierUtilsNotifier`)** — should pass; suffix check is purely "ends with," so this technically satisfies the naming rule even if awkward — that's a style nit outside this rule's scope.

---

## Alternatives Considered

- **Configurable suffix (custom string via `analysis_options_custom.yaml`)** — considered, since some teams use `Controller` or `ViewModel` project-wide instead of `Notifier`; deferred to a follow-up config option rather than blocking the initial gap-closing implementation, consistent with how `banned_identifier_usage` started fixed and later gained configurability.
- **Fire on `build()` return-type mismatch instead of class name** — rejected; DCM's rule is explicitly about naming, and return-type checks are already a separate, well-covered correctness concern unrelated to this gap.
