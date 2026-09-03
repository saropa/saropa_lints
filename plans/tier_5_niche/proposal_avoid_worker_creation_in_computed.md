# PROPOSAL: Flag Worker/Reaction Creation Inside `computed` Getters

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `require_getx_worker_dispose` (companion domain — Worker lifecycle, different package/trigger)

---

## Summary

Add `avoid_worker_creation_in_computed` to flag a reactive `Worker`/reaction/autorun/listener subscription being created (e.g. `ever(...)`, `autorun(...)`, `reaction(...)`, `worker(...)`, or a raw `.listen(...)` on a stream/observable) from inside a `computed`/derived-value getter body. A `computed` value is expected to be a pure derivation with no side effects — spinning up a worker there means a brand-new subscription is created on every recomputation, and the old one is never torn down.

**Closes gap:** all_observer_lint `avoid-worker-creation-in-computed` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Reactive/observer libraries (MobX-style `computed`, GetX-style `Rx`/`Worker`, Signals-style derived signals) all share one contract: a computed/derived value's getter is re-evaluated every time one of its dependencies changes, and the framework may call it far more often than a naive reading of the code suggests (eager recomputation, multiple observers, `computedAsync` re-runs, etc.). Anything with a side effect inside that getter body — and creating a worker/subscription is a side effect — runs once per recomputation. Because the previous worker is (by construction) local to that call and never captured for disposal, each recomputation leaks a subscription: the old worker keeps its listener attached, its closure retained, and its captured references alive. Under a UI that re-derives state frequently (scroll-driven filters, search-as-you-type, frequently-changing form validation), this can produce dozens of live-but-orphaned subscriptions within seconds. `saropa_lints` already treats worker-lifecycle correctness as a first-class concern for GetX (`require_getx_worker_dispose` in `lib/src/rules/packages/getx_rules.dart`) but that rule only checks that a worker *field* is disposed in `onClose()` — it does not catch the more fundamental mistake of never assigning the worker to a field at all because it was created inside a pure-derivation getter.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class SearchController extends GetxController {
  final _query = ''.obs;

  // A computed/derived getter — re-evaluated on every read that participates
  // in a reactive build, and again whenever `_query` changes.
  Worker get _queryWatcher => ever(_query, (String value) { // LINT
    print('query changed: $value');
  });
}
```

```dart
// MobX-style computed getter.
class ReportViewModel = _ReportViewModel with _$ReportViewModel;

abstract class _ReportViewModel with Store {
  @observable
  DateTime range = DateTime.now();

  @computed
  int get _rangeWatcher {
    autorun((_) => print('range: $range')); // LINT — side-effecting reaction inside computed
    return range.day;
  }
}
```

### Should pass (good code)

```dart
class SearchController extends GetxController {
  final _query = ''.obs;
  late final Worker _queryWorker; // OK — field, created once

  @override
  void onInit() {
    super.onInit();
    _queryWorker = ever(_query, (String value) => print('query changed: $value'));
  }

  @override
  void onClose() {
    _queryWorker.dispose(); // OK — disposed alongside creation
    super.onClose();
  }

  // Pure derivation — no side effects, safe to recompute freely.
  String get normalizedQuery => _query.value.trim().toLowerCase(); // OK
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Package-specific to reactive/observer libraries (MobX `computed`, GetX `Worker`/`Rx`, Signals derived values) that are not present in every Flutter project, and the detection relies on heuristic getter-name/annotation matching rather than a universal language construct — matches saropa's placement for other single-package behavioral rules that are valuable but not broadly applicable enough for Essential/Recommended.

---

## Edge Cases

1. **Worker created inside a regular method, not a `computed`/`@computed` getter** — should pass; the rule targets pure-derivation contexts specifically, not all methods.
2. **`computed` getter that returns the `Worker`/`Disposable` itself for the caller to manage** (e.g. `Worker get initWatcher => ever(...)`) — should still flag; even though the caller *could* store and dispose it, the getter shape still triggers a fresh worker on every read/recomputation, which is the actual bug regardless of what the caller does with the return value.
3. **`autorun`/`reaction`/`ever` call inside a `computed` getter that is provably called exactly once (e.g. guarded by a `late final` cache at the call site)** — false positive risk; the rule is a static syntactic check on the getter body and cannot see call-site caching, so document this as an accepted false-positive class with `// ignore:` as the escape hatch.
4. **Nested closures inside the `computed` getter that create the worker** (e.g. inside a callback passed to `Future(() { ever(...); })`) — should flag; still executes on every recomputation of the getter, same underlying leak.
5. **Non-reactive plain Dart getter named `computed` that has nothing to do with MobX/GetX** (naming collision) — false positive risk; scope detection to the `@computed` annotation (MobX) or a getter whose declared return type is `Worker`/`Rx*`/`Computed<...>` combined with library-specific imports being present in the file, to avoid firing on unrelated code that merely has a getter named `computed`.

---

## Alternatives Considered

- **Flag any side-effecting call (not just worker/subscription creation) inside a `computed` getter** — rejected for the initial version; that is a much broader "computed getters must be pure" rule with many more side-effect shapes to enumerate (`print`, state mutation, navigation) and a higher false-positive surface. Scoping to worker/reaction/listener creation specifically matches the cited prior art and targets the highest-severity subset (resource leaks, not just impurity).
- **Detect via type resolution only (`usesTypeResolution: true`, checking the getter's static return type)** — considered as the primary detection strategy for the `computed`-context check, since annotation-only matching would miss un-annotated MobX getters accessed via generated `_$` mixins; final scope should combine `@computed` annotation detection with GetX-idiomatic getter shapes (`Worker get ...`) rather than committing to one detection mode exclusively.

---

## Decision

---

## Implementation Notes

Package-specific rule — home is `lib/src/rules/packages/`, likely a new `mobx_rules.dart` (no existing file covers MobX `computed`/`observable`/`autorun` in `lib/src/rules/packages/`, confirmed by grep) or an addition to `getx_rules.dart` for the GetX-specific `Worker`-returning-getter case, depending on which library's syntax the implementation targets first. `applicableFileTypes` should likely stay unset (this is not a widget-specific concern) but `usesTypeResolution: true` is needed to reliably identify `Worker`/`Computed<T>` return types versus incidental naming. Reuse the getter-body-walk pattern already established in `getx_rules.dart`'s `RequireGetxWorkerDisposeRule` for locating `Worker`-typed expressions.

---

## Commits
