# PROPOSAL: Constructor Initializer-List Ordering

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_sorted_pattern_fields`, `prefer_sorted_record_fields` (sibling ordering-style rules in `lib/src/rules/data/record_pattern_rules.dart` — same "consistent ordering aids review" rationale, different AST target)

---

## Summary

Add a rule that flags a constructor's initializer list (`: field1 = x, field2 = y, super(...)`) when its entries are not ordered to match the declaration order of the corresponding fields, so initializer lists read top-to-bottom the same way the class's field declarations do.

**Closes gap:** DCM `initializers-ordering` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

saropa_lints already has two rules built on the same underlying idea — "unordered lists of named things slow review and hide missing/duplicate entries" — `prefer_sorted_pattern_fields` and `prefer_sorted_record_fields` (both in `lib/src/rules/data/record_pattern_rules.dart`), both flagging when object-pattern/record fields deviate from alphabetical order, and both quoting the identical rationale in their diagnostic message: "Unsorted ... fields slow code review and make refactoring error-prone... reduces merge conflicts when multiple developers modify the same ... definition, and makes it easier to spot missing or duplicate fields at a glance." A constructor's initializer list is structurally the same kind of ordered-list-of-names problem, just targeting field-initializer assignments (`ConstructorFieldInitializer`) instead of pattern/record fields — a long initializer list with fields assigned in random order relative to their declaration order makes it hard to visually confirm every field got initialized and easy to miss a duplicate assignment during review.

DCM (dcm.dev) ships this as `initializers-ordering`. Unlike the pattern/record rules (which sort alphabetically), the natural comparison basis for initializers is **declaration order** — matching the field order already visible just above the constructor in the same class — rather than alphabetical, since that is what DCM's rule and most style guides check, and it gives the reader a single consistent reading order across the whole class (fields, then initializers in the same sequence).

---

## Detection / Behavior

### Should flag (bad code)

```dart
class Point {
  final int x;
  final int y;
  final int z;

  Point(this.x, this.y, this.z)
      : assert(x >= 0),
        // z assigned before y — LINT, doesn't match field declaration order (x, y, z)
        ;
}

class Rect {
  final double width;
  final double height;

  Rect({required double w, required double h})
      : height = h,  // LINT — height initialized before width, but width is declared first
        width = w;
}
```

### Should pass (good code)

```dart
class Rect {
  final double width;
  final double height;

  Rect({required double w, required double h})
      : width = w,   // OK — matches declaration order
        height = h;
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: this is a readability/review-aid convention rather than a correctness concern (initializer order has no runtime effect except for the well-known `assert` ordering caveat, see Edge Cases) — the same tier level as its closest siblings `prefer_sorted_pattern_fields`/`prefer_sorted_record_fields`, which are both `LintImpact.info`-severity code-smell rules rather than Essential/Recommended-tier correctness rules.

---

## Edge Cases

1. **`super(...)` invocation position** — Dart requires the superclass constructor invocation to be the *last* entry in an initializer list; a naive "must match field order" check would incorrectly flag every valid `super(...)` call unless the rule special-cases it as always-last and excludes it from the ordering comparison against field declarations, matching DCM's own documented behavior.
2. **`assert(...)` entries interleaved with field initializers** — asserts are not field initializers and have no natural declaration-order position; the rule should either (a) ignore `AssertInitializer` nodes entirely when computing order (compare only `ConstructorFieldInitializer` entries against each other) or (b) require asserts to appear before all field initializers they logically guard — implementation should pick the option DCM documents to stay a faithful equivalent, defaulting to (a) if unclear since it produces fewer surprising diagnostics.
3. **Fields not present in the initializer list at all (initializing-formal `this.x` params, or fields with no explicit initializer)** — the rule must only compare the relative order of initializers that ARE present in the list against each other's corresponding field positions, not require every field to appear; a class mixing `this.field` shorthand params with a partial initializer list for computed fields is common and valid, and the ordering check should skip fields with no corresponding initializer-list entry when building the expected order.

---

## Alternatives Considered

- **Alphabetical ordering (matching `prefer_sorted_pattern_fields`/`prefer_sorted_record_fields`)** — considered for consistency with the sibling rules, but rejected in favor of declaration-order, since (a) DCM's `initializers-ordering` checks declaration order, not alphabetical, and matching the competitor rule's actual semantics is the point of closing this specific gap, and (b) declaration-order gives a stronger benefit here specifically: the field list is right above the constructor in the same file, so matching it (rather than an independent alphabetical sort) creates one consistent top-to-bottom reading path through the whole class, which alphabetical order would not.

---

## Decision

---

## Implementation Notes

Register via `context.addConstructorDeclaration`, walk `node.initializers` filtering to `ConstructorFieldInitializer` nodes (via `.fieldName.name`), and build the expected order from the enclosing class's `bodyMembers` `FieldDeclaration` sequence (same `node.bodyMembers` accessor already used by `MemberOrderingFormattingRule` in `lib/src/rules/stylistic/formatting_rules.dart`).

---

## Commits
