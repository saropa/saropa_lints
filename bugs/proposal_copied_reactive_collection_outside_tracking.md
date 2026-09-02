# PROPOSAL: Flag Reactive Collections Copied Outside Tracking Context

**Status: Open**

Created: 2026-09-02
Type: New rule (package-specific: `all_observer`)
Related rules: none

---

## Summary

Add `copied_reactive_collection_outside_tracking` to flag a reactive/observable collection (e.g. `ObservableList`, `ObservableMap` from the `all_observer` package) being copied (`.toList()`, spread `[...obs]`, `Map.from(obs)`) outside an observer/tracking context, which silently produces a plain, non-reactive snapshot instead of a live reference.

**Closes gap:** `all_observer_lint` `copied_reactive_collection_outside_tracking` (dart_code_metrics_presets-style package lint). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "all_observer" gaps section.

---

## Motivation

`all_observer`'s reactive collections only notify dependents when read inside a tracked context (`Observer`, `computed`, `effect`). Copying the collection outside such a context (e.g. in a plain method or constructor) creates a frozen snapshot that looks identical to the live collection but never updates — a subtle, hard-to-debug staleness bug specific to this reactive library.

---

## Detection / Behavior

Flag a method call (`.toList()`, `.toSet()`, `Map.from(...)`) or spread operator applied to a variable/field whose static type is one of `all_observer`'s reactive collection types (`ObservableList`, `ObservableSet`, `ObservableMap`), when the enclosing context is not a recognized tracking scope (not inside `Observer(builder: ...)`, `computed(...)`, or `effect(...)`).

### Should flag (bad code)

```dart
class ItemService {
  final ObservableList<Item> items = ObservableList<Item>();

  List<Item> snapshot() {
    return items.toList(); // LINT — copies reactive collection outside tracking; result never updates
  }
}
```

### Should pass (good code)

```dart
class ItemView extends StatelessWidget {
  final ObservableList<Item> items;
  const ItemView({required this.items});

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final snapshot = items.toList(); // OK — inside a tracking context, dependency is registered
        return ListView(children: snapshot.map(_buildItem).toList());
      },
    );
  }
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: package-specific rule for `all_observer`; only relevant to projects that depend on it, so it sits outside Essential/Recommended.

---

## Edge Cases

1. **Copy inside `effect(...)` callback** — should pass; tracking context.
2. **Copy of a non-reactive `List` that merely originated from a reactive source elsewhere** — should pass; the rule only inspects the static type of the copied expression itself, not its provenance.
3. **Copy inside a `computed(...)` definition** — should pass; `computed` is a tracking context.
4. **Copy assigned directly to a field for later use, never read reactively** — should flag; the same staleness risk applies regardless of destination.

---

## Alternatives Considered

- **Flag every `.toList()` call on a reactive collection regardless of context** — rejected; false-positives inside legitimate tracking contexts (`Observer`, `computed`, `effect`) would dominate and erode trust in the rule.

---

## Decision

---

## Implementation Notes

Depends on `all_observer` type detection utilities (reactive collection type names) shared with the other `all_observer`-family proposals (`dispose_reactive_resources`, `effect_without_reactive_read`); consider a shared helper module for reactive-type recognition and tracking-context detection.

---

## Commits
