# PROPOSAL: Flag Constructor Parameter Order That Doesn't Match Field Declaration Order

**Status: Implemented**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `constructor_parameters_and_fields_should_have_the_same_order` to flag a class whose constructor parameter order doesn't match the order its corresponding fields are declared in the class body — e.g. fields declared `a`, `b`, `c` but a constructor written `MyClass({required this.c, required this.b, required this.a})`. This is a pure readability/consistency rule: matching order lets a reader scan top-to-bottom and match constructor params to fields visually without hunting.

**Closes gap:** `leancode_lint` `constructor_parameters_and_fields_should_have_the_same_order` (github.com/leancodepl/flutter_corelibrary). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` `leancode_lint` section (HAVE: 9, PARTIAL: 5, GAP: 9).

---

## Motivation

Dart's constructor-body-first field-initializer syntax (`this.fieldName`) means the constructor parameter list is effectively a second declaration of the same fields, and when the two lists drift out of order the class becomes harder to review: a reader checking "did this constructor forget a field?" has to cross-reference two differently-ordered lists instead of scanning both top-to-bottom in lockstep. This drift accumulates naturally over a class's lifetime — a field gets added mid-list, or a constructor parameter gets reordered during a refactor for unrelated reasons (e.g. required-before-optional grouping) — and nothing in the language or the existing `sort_constructors_first`/member-ordering rules catches the field-vs-parameter mismatch specifically. `leancode_lint` ships this exact check as a pure consistency rule with no correctness implications, which is why it belongs at a low-friction tier.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class UserProfile {
  final String name;
  final int age;
  final String email;

  UserProfile({
    required this.email, // LINT — fields declared name, age, email but
    required this.age,   //        constructor params are email, age, name
    required this.name,
  });
}
```

### Should pass (good code)

```dart
class UserProfile {
  final String name;
  final int age;
  final String email;

  UserProfile({
    required this.name, // OK — matches field declaration order
    required this.age,
    required this.email,
  });
}
```

---

## Proposed Tier

Tier: Stylistic (opt-in)
Justification: This is a pure readability/consistency preference with zero correctness impact and a real risk of friction on classes with an intentionally grouped parameter order (e.g. required-before-optional, or params grouped by logical relationship rather than declaration order) — matching how saropa already places other formatting/consistency-only rules (e.g. member-ordering variants) at Stylistic rather than a default-enabled tier, so teams opt in deliberately rather than having it fire unsolicited on legacy code.

---

## Edge Cases

1. **Constructor with fewer parameters than fields (some fields not constructor-initialized, e.g. computed/late fields)** — should pass for the fields that ARE in the parameter list, checking only that their relative order matches; fields absent from the constructor are simply skipped from the comparison.
2. **Named vs. positional parameters mixed** — compare order within each parameter kind independently (positional params should match the order of their corresponding fields among themselves; named params likewise), since Dart requires positional-before-named at the language level regardless of field order.
3. **Constructor parameters that aren't `this.field` shorthand** (e.g. a parameter used only in the initializer list to compute a derived field) — should pass/skip; the rule only compares parameters that are direct `this.` field-forwarding, since non-forwarding parameters have no corresponding field position to match against.
4. **Multiple constructors on the same class (default + named constructors)** — check each constructor independently against the same field declaration order; a class can have one constructor correctly ordered and another that drifted.
5. **Inherited/mixed-in fields not declared in this class body** — should pass/skip; the rule only orders against fields declared directly in the enclosing class, not inherited ones a `super(...)` call might also forward.
6. **`required` keyword position or default-value expressions differing between params** — irrelevant to this rule; only the relative left-to-right ORDER of the `this.field` targets is compared, not any other parameter syntax.

---

## Alternatives Considered

- **Also enforce field declaration order match constructor parameter REQUIREDNESS grouping** (required fields first) — rejected; that's a distinct, stronger opinion than `leancode_lint`'s actual rule, which only compares order, not requiredness grouping. Conflating the two would make the rule reject valid, common patterns (optional field declared before a required one) that have nothing to do with the readability problem being solved.
- **Auto-fix that reorders constructor parameters to match field order** — worth pursuing as a follow-up quick fix once the base rule ships; reordering named parameters is generally safe (call sites use names, not position) but positional-parameter reordering would be a breaking API change for any external caller, so the fix should likely warn/skip on positional-parameter classes rather than silently reordering.

---

## Decision

---

## Implementation Notes

Candidate home: `lib/src/rules/core/class_constructor_rules.dart`, which already houses other constructor-shape rules. Detection: for each constructor declaration, collect its `this.field` parameters in left-to-right source order, collect the enclosing class's field declarations in source order, filter the field list down to only fields present in the constructor's `this.field` set (preserving field order), and compare the two filtered lists for equality — flag the constructor if they differ, reporting on the first out-of-order parameter for a precise error location.

---

## Commits
