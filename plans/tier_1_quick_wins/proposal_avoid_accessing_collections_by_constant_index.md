# PROPOSAL: Flag List Access by a Hardcoded Constant Index

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `avoid_accessing_collections_by_constant_index` to flag `list[0]`, `list[1]`, `list[2]`, etc. — indexing
a `List` with a literal integer constant — outside of the well-established `[0]`/`[length - 1]` idioms already
better expressed via `.first`/`.last`. A hardcoded numeric index into a collection is fragile: it silently
breaks (wrong element, or a `RangeError`) if the collection's population order or length changes elsewhere,
with no compile-time signal at the access site.

**Closes gap:** `awesome_lints` `avoid_accessing_collections_by_constant_index`
(github.com/LucasXu0/awesome_lints). Implementing this proposal as specified fully closes this competitive
gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Indexing a collection with a magic number (`items[2]`) couples the reader to an implicit, undocumented
assumption about the collection's contents and order that lives nowhere near the access site. Any change to
how the list is built — a new item inserted earlier, a filter added — silently shifts every subsequent
indexed access to the wrong element, and Dart's type system offers no protection against it. Named
destructuring, `.firstWhere(...)`, or an intermediate named variable communicates intent and survives
refactors; a bare numeric index does not.

---

## Detection / Behavior

### Should flag (bad code)

```dart
final name = users[2].name; // LINT — avoid_accessing_collections_by_constant_index: magic index into 'users'
```

### Should pass (good code)

```dart
final name = users.first.name; // OK — .first/.last idioms already covered separately
final admin = users.firstWhere((u) => u.isAdmin).name; // OK — intent-revealing lookup
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Readability/fragility concern rather than a runtime-safety bug — the value is real for larger
codebases doing a deep-clean pass, but too noisy for Essential/Recommended given how common small-fixed-size
tuple-like list access (`match[0]`/`match[1]` on a fixed-shape regex/CSV row) can legitimately be.

---

## Edge Cases

1. **`list[0]` / `list[list.length - 1]`** — should pass; saropa already recommends `.first`/`.last` for
   these via a separate existing rule, avoid double-flagging the same access.
2. **Indexing a `Record`-like fixed-shape list** (e.g. a 2-element list standing in for a coordinate pair,
   `point[0]`/`point[1]`) — needs discussion; arguably a legitimate fixed-arity access, but Dart records now
   offer a typed alternative — consider exempting only genuinely externally-fixed shapes (regex `Match.group`
   results, CSV row parsing) via a size/context heuristic rather than banning all non-0/non-last indices.
3. **`Map` access by key** (`map['key']`) — should pass; this rule targets `List`/`Iterable`-shaped
   constant-integer indexing only, not map key lookups.
4. **Index that is itself a named constant** (`items[kHeaderRowIndex]`) — should pass; the named constant
   already communicates intent, which is the exact readability problem this rule targets.

---

## Alternatives Considered

- **Flag ALL literal-integer indices including `[0]`** — rejected; `[0]` is idiomatic and already covered by
  saropa's existing `.first`-preference rule, duplicating the diagnostic would be redundant noise.

---

## Decision

---

## Implementation Notes

---

## Commits
