# PROPOSAL: Require Constructor Initializer List to Match Field Declaration Order

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `getters_in_member_list`

---

## Summary

Add `initializers_ordering` to flag a constructor initializer list (`: field1 = x, field2 = y, ...`) whose entries are ordered differently from the order the corresponding fields are declared in the class body. Dart already evaluates the class's field initializers top-to-bottom regardless of initializer-list order, so mismatched ordering is purely a readability trap.

**Closes gap:** `many_lints` `initializers_ordering` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

When a constructor's initializer list order doesn't match field declaration order, a reader checking "what does field X get initialized to" has to cross-reference two different orderings instead of scanning linearly. This is purely cosmetic but cheap to enforce and removes a recurring nit in code review.

---

## Detection / Behavior

Flag a `ConstructorDeclaration` whose `initializers` (excluding `super(...)`/`this(...)` redirecting calls and assertion initializers) are not in the same relative order as the matching field declarations in the enclosing class.

### Should flag (bad code)

```dart
class Point {
  final int x;
  final int y;

  Point(int a, int b)
      : y = b, // LINT — y initialized before x, but x is declared first
        x = a;
}
```

### Should pass (good code)

```dart
class Point {
  final int x;
  final int y;

  Point(int a, int b)
      : x = a, // OK — matches declaration order
        y = b;
}
```

---

## Proposed Tier

Tier: Pedantic
Justification: Cosmetic ordering rule with zero runtime/correctness impact.

---

## Edge Cases

1. **Initializer list mixing field assignments with `assert(...)`** — asserts are excluded from the ordering comparison; only field-assignment initializers are checked against each other.
2. **`super(...)` call present in the initializer list** — should not itself count toward ordering (it isn't a field-declaration-order concept); only relative order among field assignments is checked.
3. **Fields declared via constructor shorthand (`this.x`) mixed with explicit initializer-list assignments for other fields** — should compare only the initializer-list entries against the subset of fields they touch, in declared order.
4. **Single-field initializer list** — should pass; nothing to compare.

---

## Alternatives Considered

- **Auto-fix that reorders the initializer list** — recommended as a companion quick fix since reordering is mechanical and safe (no side effects between pure field assignments); include in initial implementation if straightforward.

---

## Decision

---

## Implementation Notes

---

## Commits
