# PROPOSAL: Flag Public Rx Subject Fields That Should Be Private + Stream-Exposed

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `private_subject` to flag a non-private (not `_`-prefixed) field, getter, or setter of a `Subject`-family type (`StreamController`, `Subject`, `BehaviorSubject`, `PublishSubject`, `ReplaySubject` — mainly from the `rxdart` package, but the Dart SDK's own `StreamController` is a sink-and-source type with the identical problem) declared as a class member. A `Subject` is both a sink (things can be added to it) and a source (things can be listened to) — exposing it publicly lets any caller push data into a stream that the owning class is supposed to control. The fix is to keep the `Subject` private and expose only a narrower, read-only `Stream` getter to the outside world.

**Closes gap:** ripplearc_linter `private_subject` (github.com/ripplearc/ripplearc-flutter-lint). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

This mirrors a pattern saropa_lints already enforces elsewhere: keep the mutable backing field private, expose an immutable/narrower view publicly. A public `StreamController`/`BehaviorSubject` field breaks encapsulation in exactly the same way a public mutable `List` field does — any external caller can call `.add()`, `.addError()`, or `.close()` on it, bypassing whatever invariants the owning class meant to enforce around when and how new values are emitted. This is especially common in hand-rolled Bloc-adjacent or reactive state-management code (rxdart-based ViewModels/Cubits predating or alongside `flutter_bloc`) where a `BehaviorSubject<T>` is used as the state holder — teams frequently expose it directly for convenience, then discover weeks later that a distant widget is calling `.add()` on state that was supposed to be centrally owned.

This rule depends on `rxdart` types (`Subject`, `BehaviorSubject`, `PublishSubject`, `ReplaySubject`) for its primary targets, though `StreamController` from `dart:async` is in scope unconditionally since it needs no extra dependency.

---

## Detection / Behavior

Flag any class member (field, or a getter whose declared/inferred return type) of static type `StreamController<T>`, `Subject<T>`, `BehaviorSubject<T>`, `PublishSubject<T>`, or `ReplaySubject<T>` that is declared with public visibility (no leading `_`) at the class level.

### Should flag (bad code)

```dart
import 'package:rxdart/rxdart.dart';

class CounterViewModel {
  final BehaviorSubject<int> counter = BehaviorSubject.seeded(0); // LINT — public Subject field; callers can call counter.add(...) directly

  void increment() {
    counter.add(counter.value + 1);
  }
}
```

### Should pass (good code)

```dart
import 'package:rxdart/rxdart.dart';

class CounterViewModel {
  final BehaviorSubject<int> _counter = BehaviorSubject.seeded(0); // OK — private Subject, sink is not externally reachable

  Stream<int> get counter => _counter.stream; // OK — narrow, read-only view exposed publicly

  void increment() {
    _counter.add(_counter.value + 1);
  }
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Depends on a reactive/rxdart-adjacent coding style that is not universal across Flutter/Dart projects (many use `flutter_bloc`'s `Cubit`/`Bloc` or `Notifier`-based state without ever touching `StreamController`/`Subject` directly), and `StreamController` misuse specifically is a narrower encapsulation concern rather than a correctness bug. Not suited to Essential/Recommended.

---

## Edge Cases

1. **A `StreamController`/`Subject` declared as a private field (`_controller`) with a public `.stream` getter** — should pass; this is the intended pattern.
2. **A public field of type `Stream<T>` (not `Subject`/`StreamController`)** — should pass unconditionally; `Stream` itself has no sink, so exposing it publicly is safe by construction.
3. **A public `StreamController`/`Subject` declared as a local variable inside a function, not a class member** — should pass; the rule targets class-level encapsulation, not local reactive plumbing.
4. **A `StreamController` exposed publicly but with `.add()`/`.sink` never called outside the declaring class in the actual codebase** — should still flag; the rule is about API surface, not observed usage — a public sink is a latent hazard regardless of current call sites.
5. **A getter that returns `_controller` directly (not `_controller.stream`)** — should flag the getter itself; it re-exposes the sink under a different name, defeating the purpose of the getter indirection.
6. **`late final StreamController` public field assigned in a constructor body** — should still flag; `late`/`final` modifiers don't change external mutability of the sink.

---

## Alternatives Considered

- **Only flag `BehaviorSubject`/`PublishSubject`/`ReplaySubject` (rxdart types), excluding plain `StreamController`** — rejected; `StreamController` has the identical sink-and-source shape and is at least as commonly misused, and it requires no extra dependency to detect, so excluding it would leave the more common case uncovered.
- **Quick fix that automatically renames the field to `_`-prefixed and generates a `.stream` getter** — worth pursuing as a follow-up fix once the rule ships; renaming a field used elsewhere in the class requires updating every internal reference, which is mechanical but non-trivial — deferred to keep the initial rule scope small.

---

## Decision

---

## Implementation Notes

---

## Commits
