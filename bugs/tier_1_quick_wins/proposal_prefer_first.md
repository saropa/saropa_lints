# PROPOSAL: Flag `list[0]` — Use `list.first` Instead

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_last`, `prefer_first_or_null`

---

## Summary

Add `prefer_first` to flag index-0 access on a `List` (`list[0]`), recommending `list.first` instead — `.first` reads as intent ("the first element") rather than an arithmetic coincidence, and its `StateError` on an empty list carries a clearer message than `RangeError` from `[0]`.

**Closes gap:** solid_lints `prefer_first`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` solid_lints Gaps section.

---

## Motivation

`list[0]` and `list.first` are functionally identical on a `List`, but `[0]` requires the reader to recognize "index zero" as shorthand for "the first element," whereas `.first` states that directly. This also generalizes better: `.first` works on any `Iterable` (not just index-accessible `List`), so code written with `.first` survives a later change from `List` to a lazier `Iterable` type without modification, while `list[0]` would not compile.

---

## Detection / Behavior

### Should flag (bad code)

```dart
String firstName(List<String> names) {
  return names[0]; // LINT — use names.first
}
```

### Should pass (good code)

```dart
String firstName(List<String> names) {
  return names.first; // OK
}
```

---

## Proposed Tier

Tier: Pedantic
Justification: purely stylistic, zero functional difference between `list[0]` and `list.first` on a `List`; matches saropa's placement for other index-to-named-accessor style rules.

---

## Edge Cases

1. **`list[0] = value` (assignment, not read)** — should pass; `.first` as a setter also exists on `List` (`Iterable` doesn't have a setter, but `List.first=` does), so `list[0] = value` could arguably also flag toward `list.first = value`; scope the initial rule to reads only and consider the setter case as a follow-up to avoid over-scoping v1.
2. **`list[0]` where `list` might be empty and the surrounding code explicitly checks `list.isNotEmpty` first** — should still flag; `.first` throws the same way `[0]` would on an empty list, so the rewrite is behavior-preserving regardless of the guard.
3. **Index expression that is a variable currently holding `0`, not a literal (`list[i]` where `i == 0` isn't statically known)** — should NOT flag; only flag a literal `0` index, since the rule cannot know a non-literal index is always zero.
4. **`someMap[0]` where the receiver is a `Map<int, T>`, not a `List`** — should NOT flag; scope strictly to `List`/`Iterable`-typed receivers where `.first` is a valid equivalent.

---

## Alternatives Considered

- **Also cover `Iterable.elementAt(0)`** — worth including as an additional flagged shape in the same rule, since it's the same "index zero" pattern spelled differently.

---

## Decision

---

## Implementation Notes

---

## Commits
