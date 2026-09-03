# PROPOSAL: `avoid_unrun_task` — Flag an fpdart `Task`/`TaskEither` That Is Never Run

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_unawaited_future` (parallel pattern for `Future`, see Motivation)

---

## Summary

Flag an fpdart `Task<T>` or `TaskEither<L, R>` value that is constructed (via `Task(...)`, `TaskEither(...)`, or returned from a function typed to return one) but on which `.run()` is never invoked within the same scope — an un-run `Task` is a deferred computation that silently never executes.

**Closes gap:** `many_lints` `avoid_unrun_task` (github.com/Nikoro/many_lints). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "fpdart / functional-programming ecosystem" theme.

---

## Motivation

fpdart's `Task<T>` wraps `Future<T> Function()` — a computation is only performed when `.run()` (or a combinator like `.flatMap`/`.map` chained through to an eventual `.run()`) is called; constructing a `Task` does nothing by itself. This makes an un-run `Task` a genuine, easy-to-write bug: the code reads as if an effect was fired (a `Task` was built with all its arguments, sometimes even assigned to a well-named variable like `saveTask`), but nothing actually happens at runtime because `.run()` was never called — no exception, no log, just silent no-op behavior. This is structurally the same failure mode saropa's existing `AvoidUnawaitedFutureRule` (`avoid_unawaited_future`, `lib/src/rules/core/async_rules.dart:3514`) targets for plain `Future`s — a value representing a deferred/asynchronous effect that is constructed but never "activated" — except for `Task`, the un-activation is total silence rather than an unhandled-error risk, since a raw `Future` at least runs eagerly once created while a `Task` never runs at all without an explicit `.run()`.

---

## Detection / Behavior

### Should flag (bad code)

```dart
import 'package:fpdart/fpdart.dart';

Task<void> saveUser(User user) {
  return Task(() async => repository.save(user));
}

void handleSubmit(User user) {
  final saveTask = saveUser(user); // LINT — Task constructed, .run() never called
}
```

### Should pass (good code)

```dart
import 'package:fpdart/fpdart.dart';

Task<void> saveUser(User user) {
  return Task(() async => repository.save(user));
}

Future<void> handleSubmit(User user) async {
  await saveUser(user).run(); // OK — .run() invoked
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: fpdart is a niche, opt-in functional-programming dependency — this rule and the rest of the fpdart family should only activate for projects that actually use it, matching the tier placement of other package-specific opt-in rules; Comprehensive keeps it out of the default Essential/Recommended surface for the majority of projects with no fpdart dependency.

---

## Edge Cases

1. **`Task` passed as an argument to another function** (`someHandler(saveUser(user))`) — should pass; the rule cannot know whether the callee runs it, and flagging would produce false positives on legitimate composition (e.g. passing to a retry combinator).
2. **`Task` stored as a class field for later use** (`this._pendingTask = saveUser(user);`) — should pass; deferred execution via a stored field is a common, intentional pattern (e.g. cancellable/queued work) and the eventual `.run()` call may be in a different method or file.
3. **`Task` returned directly from a function** (`Task<void> f() => saveUser(user);`) — should pass; the caller is expected to run it, this is normal fpdart composition, not the bug.
4. **`.run()` called via a chained combinator that eventually calls it** (`saveUser(user).map((_) => true).run()`) — should pass; walk the method-chain root back to the `Task`/`TaskEither` construction and confirm `.run()` terminates the chain.
5. **`TaskEither` combined via `Task.sequential`/similar batch combinators without a direct per-instance `.run()`** — should pass if the batch combinator itself is run; requires recognizing a small set of known fpdart combinators that consume a `Task` without an immediate `.run()` call on the individual instance.

---

## Alternatives Considered

- **Model this as a general "unused/never-invoked value" rule** rather than fpdart-specific — rejected; the "constructed but not activated" hazard is specific to fpdart's lazy `Task`/`TaskEither` semantics (a plain `Future` at least starts running on creation), so a generic unused-value check would either miss the activation semantics or produce noise on unrelated types.
- **Extend `avoid_unawaited_future` to also cover `Task`** — rejected; the detection logic is different enough (looking for a missing `.run()` call rather than a missing `await`/`unawaited()` wrapper on an already-started `Future`) to warrant a separate rule, though the two should share the "effect constructed but not activated" framing in documentation for discoverability.

---

## Decision

---

## Implementation Notes

Package-specific (fpdart) — gate on the project actually depending on `fpdart` (see how other package-specific rule files in `lib/src/rules/packages/` detect their target dependency, typically via `pubspec.yaml` presence or import-based scoping) so the rule is silent for the vast majority of projects with no fpdart dependency. No existing "fpdart" or "TaskEither" hits anywhere in `lib/src/rules/` today — this would be the first rule in a new fpdart-aware family (~26 unique gaps identified in `plans/GAP_ANALYSIS.md`'s fpdart theme); consider whether this warrants a new `lib/src/rules/packages/fpdart_rules.dart` file shared across that family rather than a one-off.

---

## Commits
