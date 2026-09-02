# PROPOSAL: Require `Cubit` Suffix on Cubit Class Names

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `none`

---

## Summary

Add `add_cubit_suffix_for_your_cubits` to require that any class extending `Cubit<State>` (from the `bloc` package) is named with a `Cubit` suffix (e.g. `CounterCubit`, not `Counter`). This is a naming-consistency rule for `bloc`/`flutter_bloc` codebases — it depends on the `bloc` package being present.

**Closes gap:** `leancode_lint` `add_cubit_suffix_for_your_cubits` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

**Package dependency:** Requires the `bloc` package (`Cubit<State>` base class) to be meaningful; saropa_lints already ships Bloc-family rules, so this fits existing package-specific coverage.

---

## Motivation

In Bloc-based codebases, distinguishing a `Cubit` from a plain state/model class by name alone (rather than having to check its superclass) speeds up code review and navigation, especially in large feature folders with dozens of state-management classes. `leancode_lint` ships this as a mechanical naming rule for LeanCode's production Bloc codebases; saropa_lints already covers other Bloc-specific patterns (event/state class shapes), so this is a natural, low-risk extension.

---

## Detection / Behavior

Flag any class declaration whose superclass (or one of its type arguments' resolved supertype chain) is `Cubit<...>` and whose class name does not end with `Cubit`.

### Should flag (bad code)

```dart
class Counter extends Cubit<int> { // LINT — class extends Cubit but name doesn't end with "Cubit"
  Counter() : super(0);
}
```

### Should pass (good code)

```dart
class CounterCubit extends Cubit<int> { // OK
  CounterCubit() : super(0);
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Package-specific (`bloc`) naming-consistency rule with a mechanical fix; Comprehensive matches saropa's placement for opt-in ecosystem-specific style rules rather than a universally-applicable default.

---

## Edge Cases

1. **Class extends a project-local base class that itself extends `Cubit`** (e.g. `abstract class BaseCubit<S> extends Cubit<S> {}`) — should flag the concrete subclass too if it still lacks the suffix, since the resolved supertype chain includes `Cubit`.
2. **Abstract Cubit base classes meant to be extended, already named without the suffix by convention** (`abstract class BaseCubit<S>`) — should pass; `BaseCubit` already ends with `Cubit`... if instead named `abstract class Base<S> extends Cubit<S>` it should flag same as concrete classes, no special-casing for `abstract`.
3. **`HydratedCubit<State>` (from `hydrated_bloc`) subclasses** — should flag the same way; `HydratedCubit` itself is a `Cubit` subtype.
4. **Class name ends with `Cubit` but as a substring, not suffix** (`CubitHelper`) — should pass only if it's not itself extending `Cubit`; if it does extend `Cubit` and is literally named e.g. `MyCubitThing`, the check is suffix-based (`endsWith('Cubit')`), so `MyCubitThing` still fails since it doesn't end with the literal suffix.

---

## Alternatives Considered

- **Regex-match `Cubit` anywhere in the name** — rejected; suffix enforcement is the actual convention and anywhere-match would accept misleading names like `CubitAwareWidget`.

---

## Decision

---

## Implementation Notes

---

## Commits
