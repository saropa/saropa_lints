# PROPOSAL: Handle Bloc Event Subclasses

**Status: Open**

Created: 2026-09-02

**Closes gap:** `bloc_lint` `handle-bloc-event-subclasses` (pub.dev). See `plans/GAP_ANALYSIS.md` Gap Theme 4 — build with the Bloc-completeness batch rather than standalone.

## Summary

Flags a sealed Bloc `Event` type that has a subclass with no corresponding `on<SubclassEvent>(...)` handler registered in the owning `Bloc`'s constructor.

## Existing Coverage

`lib/src/rules/packages/bloc_rules.dart` has over 50 Bloc-related rules but none check event-handler completeness against a sealed event hierarchy. The closest are `AvoidDuplicateBlocEventHandlersRule` (flags *duplicate* `on<T>` registrations — the opposite problem), `PreferSealedEventsRule`/`PreferSealedBlocEventsRule`/`RequireBlocEventSealedRule` (require the event type to be `sealed`, a prerequisite for this rule but not the same check), and `AvoidLongEventHandlersRule` (handler body size, unrelated). No duplicate — this is a genuine gap.

## Motivation

When a Bloc's event type is `sealed`, Dart's exhaustiveness checking guarantees a `switch` on the event covers every subclass — but Bloc's `on<T>()` registration API is not a switch statement, so the analyzer gives no such guarantee there. Adding a new event subclass without registering an `on<NewEvent>()` handler compiles cleanly and the event is silently dropped at runtime: `add(NewEvent())` does nothing, and the bug typically surfaces only when a QA tester or user triggers the new feature and observes no UI change, with no exception or log line pointing at the cause.

## Detection / Behavior

Triggers when a `Bloc<Event, State>` subclass's constructor body registers `on<T>()` handlers, the `Event` type is `sealed`, and at least one subclass of that sealed type (found via the analyzer's sealed-subtype enumeration, same mechanism exhaustiveness checking uses) has no matching `on<Subclass>()` call anywhere in the constructor.

```dart
// BAD
sealed class CounterEvent {}
class Increment extends CounterEvent {}
class Decrement extends CounterEvent {}
class Reset extends CounterEvent {} // added later, handler forgotten

class CounterBloc extends Bloc<CounterEvent, int> {
  CounterBloc() : super(0) {
    on<Increment>((event, emit) => emit(state + 1));
    on<Decrement>((event, emit) => emit(state - 1));
    // Reset has no registered handler — add(Reset()) is silently dropped.
  }
}

// GOOD
class CounterBloc extends Bloc<CounterEvent, int> {
  CounterBloc() : super(0) {
    on<Increment>((event, emit) => emit(state + 1));
    on<Decrement>((event, emit) => emit(state - 1));
    on<Reset>((event, emit) => emit(0));
  }
}
```

## Quick Fix

Insert a stub `on<MissingSubclass>((event, emit) { /* TODO: handle */ })` registration for each unhandled subclass — flagged as an exception to this package's "no insert-TODO quick fixes" policy because the alternative (silently dropped events) is strictly worse than a visible TODO stub; alternatively, ship as detection-only with no quick fix if the policy is held firm, requiring the developer to write the real handler by hand.

## Alternatives Considered

Relying solely on Dart's own exhaustiveness checking (by requiring event handling via a `switch` inside a single `on<CounterEvent>` handler instead of Bloc's per-type `on<T>()` API) was considered, but that would mean recommending against Bloc's idiomatic API rather than validating correct use of it — out of scope for a lint rule. Building this as part of the dedicated Bloc-completeness batch (per `plans/GAP_ANALYSIS.md` Gap Theme 4) rather than standalone avoids duplicating shared sealed-subtype enumeration logic across multiple one-off PRs.
