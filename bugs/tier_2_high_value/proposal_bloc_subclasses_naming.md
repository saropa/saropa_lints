# PROPOSAL: Enforce Consistent Naming for Bloc/Cubit Event and State Subclasses

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_bloc_event_mutation` (relies on the same `...Event`-suffix naming convention to identify event classes), `require_immutable_bloc_state` (relies on the same `...State`-suffix convention)

---

## Summary

Add `bloc_subclasses_naming` to flag Bloc/Cubit event and state subclasses whose name doesn't incorporate their parent Bloc/Cubit's base name in a consistent, predictable position — e.g. for `CounterBloc` with base event `CounterEvent`, concrete subclasses should read `CounterEventIncrement`/`CounterIncrementEvent` (project picks one convention), not unrelated names like `Increment` or `DoIncrement`.

**Closes gap:** leancode_lint `bloc-subclasses-naming` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`lib/src/rules/packages/bloc_rules.dart` already leans on the informal `...Event`/`...State` suffix convention to *identify* event and state classes (`AvoidBlocEventMutationRule` checks `className.endsWith('Event')`, and the file's own comment at line ~405 notes a `...State`-named class with no Bloc/Cubit participation is treated as a plain domain type) — but nothing enforces that the *concrete subclasses* of those base classes are themselves named consistently. In a codebase with several Blocs, unqualified event names like `Increment`, `Refresh`, or `Load` collide across features, force readers to jump to the import to know which Bloc an event belongs to, and make IDE searches ("find all usages of Increment") return noise from unrelated Blocs. leancode_lint ships `bloc-subclasses-naming` specifically to keep every event/state class self-describing by name alone — `CounterEventIncrement extends CounterEvent` tells the reader everything without an import.

---

## Detection / Behavior

### Should flag (bad code)

```dart
abstract class CounterEvent {}
class CounterState {}

class Increment extends CounterEvent {} // LINT — name doesn't reference CounterEvent/CounterBloc
class Reset extends CounterEvent {} // LINT

class Loaded extends CounterState {} // LINT — name doesn't reference CounterState/CounterBloc
```

### Should pass (good code)

```dart
abstract class CounterEvent {}
class CounterState {}

class CounterEventIncrement extends CounterEvent {} // OK — carries the base name
class CounterEventReset extends CounterEvent {} // OK

class CounterStateLoaded extends CounterState {} // OK
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Pure naming-convention/readability rule with no correctness or runtime impact — matches saropa's placement for other stylistic/consistency checks that are valuable for larger teams enforcing a shared convention but too opinionated to force on Essential/Recommended, where projects may already have an established (different) naming style.

---

## Edge Cases

1. **Sealed/abstract base class itself** (`CounterEvent`, `CounterState`) — should pass; the rule targets concrete subclasses, not the base class declaration.
2. **A Bloc/Cubit's base event/state class that doesn't follow `<Feature>Event`/`<Feature>State` naming** (e.g. a base class literally named `Event`) — needs discussion; if the base class name itself is generic, there is no meaningful prefix to require on subclasses, so the rule should either skip files where the base class name has no feature-specific segment, or fall back to matching against the enclosing Bloc/Cubit class name (`CounterBloc`) directly rather than the base event/state class name.
3. **Third-party or generated event/state classes** (e.g. `HydratedCubit`'s serialized state helpers, `freezed`-generated `_$CounterState` variants) — should pass; only flag hand-authored subclasses in the user's own source, and standard generated-file suppression (`.freezed.dart`, `.g.dart`) applies.
4. **A class that extends `CounterEvent` but is unrelated to the Bloc pattern** (e.g. a coincidentally-named domain event in an event-sourcing system with no `Bloc<CounterEvent, ...>` in scope) — false positive risk; scope detection to files/classes where the base class name is provably used as the event/state type argument of an actual `Bloc<...>`/`Cubit<...>` declaration in the same library, not merely `extends`.
5. **Equatable/copyWith mixins added to the subclass** (`class CounterEventIncrement extends CounterEvent with EquatableMixin`) — should pass; the naming check only inspects the class's own declared name, not its mixin list.

---

## Alternatives Considered

- **Enforce one specific convention (suffix-only, `IncrementCounterEvent`)** — rejected in favor of a configurable prefix/suffix choice (`CounterEventIncrement` vs. `CounterIncrementEvent`); codebases differ on which reads better, and leancode_lint's own rule is convention-flexible rather than prescribing one fixed pattern, so hardcoding one order would force unnecessary renames on adopting teams.
- **Infer the naming rule from the Bloc/Cubit class name directly** (`CounterBloc` -> subclasses must contain `Counter`) instead of from the base event/state class name — considered as the primary matching strategy since it is more robust to base classes with generic names (edge case 2); final implementation should likely combine both signals, preferring the Bloc/Cubit class name when the base event/state class name is not itself feature-specific.

---

## Decision

---

## Implementation Notes

Candidate home: `lib/src/rules/packages/bloc_rules.dart`, alongside `AvoidBlocEventMutationRule` and `RequireImmutableBlocStateRule` — reuse the file's existing `endsWith('Event')`/`endsWith('State')` base-class identification pattern (line ~861, and the `...State`-with-no-Bloc-participation exclusion noted near line ~405) to first locate the base event/state class, then walk the library for `ClassDeclaration extendsClause.superclass` references back to it and check the subclass name contains the base class's feature-name segment.

---

## Commits
