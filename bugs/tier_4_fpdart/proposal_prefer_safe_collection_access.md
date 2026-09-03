# PROPOSAL: Flag Unsafe Collection Indexing on fpdart-Typed Values — Use `Option`-Returning Extensions Instead

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

**Package dependency:** `fpdart`. This rule only applies to projects using `package:fpdart` and should only run when fpdart is a declared dependency.

---

## Summary

Add `prefer_safe_collection_access` to flag direct `list[index]` / `map[key]` access in a codebase that has already opted into fpdart, recommending fpdart's `Option`-returning safe-access extensions (`list.getOption(index)`, `map.lookupOption(key)`) instead, so a possible out-of-range/missing-key failure is represented in the type system rather than as a runtime exception.

**Closes gap:** many_lints `prefer_safe_collection_access` (fpdart family). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` Gap Theme 1.

---

## Motivation

A project that has adopted fpdart for error handling is making a deliberate bet that failure modes should be explicit in return types (`Option`/`Either`) rather than thrown exceptions. Direct `[]` indexing on `List`/`Map` throws `RangeError`/returns `null` respectively — an escape hatch back into unchecked, exception-based failure that undermines the rest of the fpdart-typed call chain it feeds into.

---

## Detection / Behavior

Flag `IndexExpression` (`list[index]`) on a `List`-typed receiver, and `map[key]` access on a `Map`-typed receiver, when the result flows into an fpdart-typed context (assigned to an `Option`/`Either` variable, passed as an argument to an fpdart combinator, or used inside a function whose return type is `Option`/`Either`/`TaskEither`) — scoping the rule to fpdart-adjacent code rather than every collection index in the codebase, to avoid blanket-banning ordinary indexing outside the functional pipeline.

### Should flag (bad code)

```dart
Option<int> firstPositive(List<int> values) {
  final first = values[0]; // LINT — use values.getOption(0) inside an Option-returning function
  return first > 0 ? Some(first) : const None();
}
```

### Should pass (good code)

```dart
Option<int> firstPositive(List<int> values) {
  return values.getOption(0).flatMap(
    (first) => first > 0 ? Some(first) : const None(),
  ); // OK
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: fpdart-specific idiom, scoped to functional-pipeline code; matches the rest of the fpdart family's tier placement.

---

## Edge Cases

1. **Index access outside any `Option`/`Either`/`TaskEither`-returning context (ordinary imperative code)** — should pass; the rule is scoped to fpdart-typed flows specifically, not a blanket "never index a list" rule (that would duplicate `no_direct_iterable_access`/`prefer_list_first` territory, which is a separate, non-fpdart gap).
2. **Index access already guarded by a prior length check (`if (values.length > index)`)** — should pass; the risk `getOption` addresses is already mitigated, and forcing a rewrite here adds no safety.
3. **`map[key]` used only for existence checks (`map[key] != null`)** — should flag toward `map.lookupOption(key).isSome()`, since the existence-check idiom is equally served by the `Option` API.

---

## Alternatives Considered

- **Flag every `[]` index access project-wide regardless of fpdart context** — rejected; too broad, would duplicate `no_direct_iterable_access`'s territory (a separate non-fpdart gap) and produce noise in code that never touches fpdart types.

---

## Decision

---

## Implementation Notes

---

## Commits
