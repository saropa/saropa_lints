# BUG: `avoid_unsafe_reduce` — False positive on inline list literal with known element count

**Status: Fixed**

Created: 2026-09-05
Rule: `avoid_unsafe_reduce`
File: `lib/src/rules/data/collection_rules.dart` (line ~1166)
Severity: False positive
Rule version: v7

---

## Summary

The rule fires on `.reduce()` called on an inline list literal `[a, b, c].reduce(...)` that always has exactly 3 elements. `reduce()` on a non-empty literal list can never throw `StateError`. The rule's heuristic ("calling reduce() on an empty collection throws") does not apply when the collection is a compile-time-known non-empty list literal.

---

## Attribution Evidence

```bash
grep -rn "'avoid_unsafe_reduce'" lib/src/rules/
# lib/src/rules/data/collection_rules.dart:1166:    'avoid_unsafe_reduce',
```

---

## Reproducer

```dart
// Inline list literal — always 3 elements, never empty.
final min = [
  prev[j] + 1,
  curr[j - 1] + 1,
  prev[j - 1] + cost,
].reduce((a, b) => a < b ? a : b); // LINT — but should NOT lint
```

**Frequency:** Always — fires on any `.reduce()` regardless of receiver type.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — a list literal with ≥1 element cannot be empty |
| **Actual** | `[avoid_unsafe_reduce] Calling reduce() on an empty collection throws a StateError` |

---

## Root Cause

### Hypothesis A: Rule does not check for ListLiteral receiver

The rule flags every `.reduce()` call without checking whether the receiver is a `ListLiteral` (or `SetLiteral`) AST node with a known, non-zero element count. When the receiver is a literal with visible elements, emptiness is statically impossible.

---

## Suggested Fix

Before reporting, check if the receiver expression is a `ListLiteral` or `SetLiteral` node. If `node.elements.isNotEmpty`, skip — the collection is provably non-empty.

---

## Fixture Gap

1. **reduce() on inline list literal with elements** — expect NO lint
2. **reduce() on variable of type List** — expect LINT
3. **reduce() on empty list literal `[].reduce(...)`** — expect LINT
4. **reduce() after `.where()` filter** — expect LINT

---

## Environment

- saropa_lints version: current (unreleased)
- Triggering file: `lib/src/rule_name_utils.dart:60`
