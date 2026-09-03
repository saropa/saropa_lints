# PROPOSAL: Extend `require_bloc_event_sealed` With Handler Exhaustiveness Check

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `require_bloc_event_sealed`

---

## Summary

Extend `require_bloc_event_sealed` to also verify that the Bloc's event handler (`on<Event>(...)` registrations, or a `when`/`switch` dispatch over the event) covers every subclass of the sealed event base class, matching DCM's `handle-bloc-event-subclasses`, which checks handler coverage, not just that the base class is `sealed`.

**Closes gap:** DCM `handle-bloc-event-subclasses` (dcm.dev) — currently PARTIAL via saropa's `require_bloc_event_sealed`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" PARTIAL matches table.

---

## Motivation

`lib/src/rules/packages/bloc_rules.dart:4236-4290` implements `RequireBlocEventSealedRule`. Its entire check is:

```dart
context.addClassDeclaration((ClassDeclaration node) {
  final name = node.nameToken.lexeme;
  if (!name.endsWith('Event')) return;

  // Check if it's abstract but not sealed
  if (node.abstractKeyword != null && node.sealedKeyword == null) {
    if (node.bodyMembers.isEmpty || _looksLikeBlocEvent(node)) {
      reporter.atNode(node);
    }
  }
});
```

It only inspects the event base class declaration itself. It never looks at the `Bloc` subclass that consumes the events, so it cannot tell whether `on<SomeEventSubclass>(...)` handlers exist for every event subtype. Marking the base class `sealed` is a necessary but not sufficient step toward exhaustiveness — the actual bug DCM's rule prevents is a developer adding a new event subclass (`final class RefreshEvent extends CounterEvent {}`) and forgetting to register a corresponding `on<RefreshEvent>(...)` handler in the `Bloc` constructor, so the event is silently swallowed at runtime with no compiler or lint error. `sealed` alone gives exhaustiveness for `switch`/`when` pattern matching *if the developer uses one*, but Bloc's dominant idiom is `on<T>(handler)` registration in the constructor, which the Dart compiler does not check for exhaustiveness at all.

## Detection / Behavior

### Should flag (bad code)

```dart
sealed class CounterEvent {}
final class IncrementEvent extends CounterEvent {}
final class DecrementEvent extends CounterEvent {}
final class ResetEvent extends CounterEvent {} // new subclass, no handler below

class CounterBloc extends Bloc<CounterEvent, int> {
  CounterBloc() : super(0) {
    on<IncrementEvent>((event, emit) => emit(state + 1));
    on<DecrementEvent>((event, emit) => emit(state - 1));
    // LINT — ResetEvent has no on<ResetEvent>(...) registration
  }
}
```

### Should pass (good code)

```dart
sealed class CounterEvent {}
final class IncrementEvent extends CounterEvent {}
final class DecrementEvent extends CounterEvent {}
final class ResetEvent extends CounterEvent {}

class CounterBloc extends Bloc<CounterEvent, int> {
  CounterBloc() : super(0) {
    on<IncrementEvent>((event, emit) => emit(state + 1));
    on<DecrementEvent>((event, emit) => emit(state - 1));
    on<ResetEvent>((event, emit) => emit(0)); // OK — every subclass handled
  }
}
```

## Proposed Tier

Tier: Comprehensive

Justification: keep parity with the existing rule's tier — `require_bloc_event_sealed` is in `comprehensiveOnlyRules` (`lib/src/tiers.dart` line 3210). Cross-declaration exhaustiveness analysis (base class → subclasses → Bloc constructor body) is exactly the kind of whole-class-graph check the Comprehensive tier is reserved for; it is not appropriate for Essential/Recommended given the higher false-positive surface of resolving inheritance and constructor bodies together.

## Edge Cases

1. **Abstract event subclasses** (e.g. an intermediate `sealed class LoadingEvent extends CounterEvent {}` with its own subclasses) — only leaf (non-abstract, non-sealed) subclasses need a handler; intermediate sealed nodes should be excluded from the "needs a handler" set.
2. **Handler registered for a supertype that covers multiple subclasses** — if a developer writes `on<CounterEvent>((event, emit) { switch (event) { ... } })` instead of per-subclass `on<T>`, the rule must recognize the `switch`/`when` inside that single handler as covering exhaustiveness, and in turn should apply Dart's own exhaustiveness checking (or a similar case-matching walk) rather than double-flagging.
3. **Event class in a different file from the Bloc** — the rule needs `usesTypeResolution` and cross-file lookup of subclasses (already partially possible via `InterfaceElement.allSubtypes` where the analyzer's type system is available) or a scoped fallback that finds subclasses within the compilation unit's library; document limits so it doesn't silently under-report.
4. **`on<T>()` registered outside the constructor** (added in a helper method called from the constructor) — should still count as handled if statically resolvable; otherwise this is a documented false-negative rather than a false-positive risk, which is acceptable per the project's bias toward avoiding false positives.
5. **Non-sealed event hierarchies** (the case the base rule already flags) — the new exhaustiveness check should only run once the base class is confirmed `sealed`, since exhaustiveness is undefined/unenforceable for a non-sealed hierarchy; this preserves the existing rule's behavior for that case unchanged.

## Alternatives Considered

- **New standalone rule** (`require_bloc_event_handler_exhaustive`) — rejected because DCM's `handle-bloc-event-subclasses` is a single rule covering exactly this sealed-base + handler-coverage relationship; splitting it would mean two saropa rules for one DCM rule, complicating the parity mapping documented in `plans/GAP_ANALYSIS.md`.
- **Rely on Dart's own exhaustiveness checker via `switch` statements** — insufficient because Bloc's `on<T>()` idiom is a runtime-registered callback map, not a `switch`/`when` expression, so the compiler's pattern-exhaustiveness checking never applies to it.

---

## Decision

---

## Implementation Notes

Extend `RequireBlocEventSealedRule` (or add a companion visitor invoked from the same rule) to, after confirming `sealed class XEvent`, collect all `ClassDeclaration`s in the resolved library whose `extendsClause` resolves to `XEvent`, then walk the `Bloc<XEvent, S>` subclass's constructor body for `on<T>(...)` invocations (`context.addMethodInvocation` filtering `node.methodName.name == 'on'` with a type-argument check) and report on the sealed base class (or the Bloc constructor) for any uncovered subclass.

---

## Commits
