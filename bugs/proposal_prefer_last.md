# PROPOSAL: Flag `list[list.length - 1]` — Use `list.last` Instead

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_first`

---

## Summary

Add `prefer_last` to flag `list[list.length - 1]` (index-length-minus-one access on a `List`), recommending `list.last` instead — same rationale as `prefer_first`: `.last` states intent directly and works on any `Iterable`, not just index-accessible `List`.

**Closes gap:** solid_lints `prefer_last`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` solid_lints Gaps section.

---

## Motivation

`list[list.length - 1]` requires the reader to do the arithmetic to realize it means "the last element," and duplicates the `list` reference (once as the receiver, once inside the index expression) — a classic spot for a copy-paste bug if `list` is renamed in one place but not the other. `.last` eliminates both problems and, like `.first`, generalizes to any `Iterable`.

---

## Detection / Behavior

### Should flag (bad code)

```dart
String lastName(List<String> names) {
  return names[names.length - 1]; // LINT — use names.last
}
```

### Should pass (good code)

```dart
String lastName(List<String> names) {
  return names.last; // OK
}
```

---

## Proposed Tier

Tier: Pedantic
Justification: purely stylistic, zero functional difference between `list[list.length - 1]` and `list.last`; matches `prefer_first`'s tier placement.

---

## Edge Cases

1. **The two `list` references in the index expression refer to different receivers (`a[b.length - 1]`)** — should NOT flag; this is not the safe `.last` shape and the two collections may have different lengths, so flagging it would suggest an incorrect rewrite.
2. **`list[list.length - 1] = value` (assignment)** — should pass in the initial rule scope (reads only), same reasoning as `prefer_first`'s setter edge case; consider as a follow-up.
3. **Off-by-one variants (`list[list.length - 2]`, second-to-last)** — should NOT flag; only the exact `length - 1` shape maps to `.last`.
4. **`list.length - 1` written with the subtraction on the other side (`-1 + list.length`)** — should flag identically if AST-level constant folding treats both as equivalent; otherwise defer to whichever ordering is idiomatic and documented as the detected shape.

---

## Alternatives Considered

- **Also cover `Iterable.elementAt(list.length - 1)`** — worth including as an additional flagged shape in the same rule, mirroring `prefer_first`'s `elementAt(0)` case.

---

## Decision

---

## Implementation Notes

---

## Commits
