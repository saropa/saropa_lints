# PROPOSAL: Flag Direct `list[index]` Access in Favor of a Bounds-Safe Accessor

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_dynamic_calls` (core lints)

---

## Summary

Add `no_direct_iterable_access` to flag direct index access (`list[index]`) on `List`/other indexable collections, suggesting a bounds-safe alternative such as `.elementAtOrNull(index)` or a project-provided `safeAt()` extension that returns `null`/a default instead of throwing `RangeError`.

**Closes gap:** `flutter_custom_lints` `no_direct_iterable_access` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`list[index]` throws `RangeError` the moment `index` is out of bounds, and that failure mode is easy to miss when the index comes from user input, an API response, or a computed offset rather than a literal loop counter. A bounds-safe accessor turns a crash into a `null` the caller must explicitly handle, which is the same defensive posture saropa_lints already takes with nullable-safe collection access.

---

## Detection / Behavior

### Should flag (bad code)

```dart
String firstItemLabel(List<String> items) {
  return items[0]; // LINT — direct index access, no bounds check
}
```

### Should pass (good code)

```dart
String firstItemLabel(List<String> items) {
  return items.elementAtOrNull(0) ?? ''; // OK — bounds-safe accessor with an explicit fallback
}
```

---

## Proposed Tier

Tier: Professional
Justification: `RangeError` crashes are a real production risk, but flagging every literal-index access (including provably-safe ones inside a bounds-checked loop) is noisy enough to place above Essential/Recommended.

---

## Edge Cases

1. **Index access immediately preceded by an explicit bounds check (`if (index < list.length) list[index]`)** — should pass; the developer has already guarded the access.
2. **Index access inside a `for (var i = 0; i < list.length; i++)` loop using the loop variable** — should pass; the loop condition provably bounds `i`.
3. **Fixed-size literal list with a constant, in-range index (`const [1, 2, 3][1]`)** — should pass; statically provable safety.
4. **`Map` bracket access (`map[key]`)** — should pass; `Map` access returns `null` for a missing key rather than throwing, so it is not the hazard this rule targets.

---

## Alternatives Considered

- **Flag `Map` access too** — rejected; `Map`'s `[]` already returns `null` on a miss, so it has none of the crash risk that motivates this rule for `List`.

---

## Decision

---

## Implementation Notes

---

## Commits
