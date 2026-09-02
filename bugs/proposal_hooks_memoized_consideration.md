# PROPOSAL: Flag Expensive Inline Computation Not Wrapped in useMemoized

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `hooks_extends`

---

## Summary

Add `hooks_memoized_consideration` to flag an expensive-looking initializer (collection sort/filter/map chains, heavy object construction, regex compilation) computed inline inside a `HookWidget.build()` without wrapping it in `useMemoized()`. Un-memoized expensive work re-runs on every rebuild instead of only when its dependencies change.

**Closes gap:** `flutter_hooks_lint` `hooks_memoized_consideration` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

A `HookWidget`'s `build()` runs on every rebuild, same as any widget. Filtering/sorting a list, parsing JSON, or compiling a `RegExp` directly in `build()` repeats that work on every frame-triggering rebuild even when the inputs haven't changed. `useMemoized(() => ..., [deps])` caches the result until a dependency changes — this rule nudges authors toward that pattern the same way `avoid_expensive_build_widgets`-style rules do for plain widgets.

---

## Detection / Behavior

Only applies inside a `HookWidget`/`HookConsumerWidget` `build()` method (or a custom hook function). Flag a local variable initializer that is a method chain of 2+ calls from `.where`, `.map`, `.sort`, `.sorted`, `RegExp(...)`, or a constructor call to a class annotated/known as expensive, when the initializer is not the argument to `useMemoized(...)`.

### Should flag (bad code)

```dart
class ItemList extends HookWidget {
  final List<Item> items;
  const ItemList(this.items);

  @override
  Widget build(BuildContext context) {
    final sorted = items.where((i) => i.active).toList()..sort((a, b) => a.name.compareTo(b.name)); // LINT — expensive chain recomputed every rebuild
    return ListView(children: sorted.map((i) => Text(i.name)).toList());
  }
}
```

### Should pass (good code)

```dart
class ItemList extends HookWidget {
  final List<Item> items;
  const ItemList(this.items);

  @override
  Widget build(BuildContext context) {
    final sorted = useMemoized(
      () => items.where((i) => i.active).toList()..sort((a, b) => a.name.compareTo(b.name)), // OK — cached, recomputed only when [items] changes
      [items],
    );
    return ListView(children: sorted.map((i) => Text(i.name)).toList());
  }
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Performance-advisory heuristic on a package-specific pattern; risks false positives on genuinely cheap chains, so it belongs past Professional where teams doing a deeper perf pass opt in.

---

## Edge Cases

1. **Trivial chain (`items.map((i) => i.id).toList()` with < 2 links)** — should pass; the threshold avoids flagging cheap, common patterns.
2. **Chain already inside `useMemoized(...)`** — should pass regardless of complexity.
3. **`useState(() => expensiveInit())` initializer** — should discuss; `useState`'s initializer already only runs once, so it should be exempted the same as `useMemoized`.
4. **Widget without hooks but with the same expensive-chain pattern** — out of scope; belongs to a general (non-hooks) `avoid_expensive_build_widgets`-style rule, not this one.

---

## Alternatives Considered

- **Static complexity threshold based on Big-O inference** — rejected as infeasible for a lint rule; use a simple method-chain-length heuristic instead, consistent with how saropa's other "expensive build" rules are scoped.

---

## Decision

---

## Implementation Notes

---

## Commits
