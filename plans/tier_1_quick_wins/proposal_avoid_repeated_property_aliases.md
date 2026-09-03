# PROPOSAL: Flag Multiple Properties That Are Aliases of the Same Underlying Value

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_local_contract_key_constants`, `avoid_final_with_getter`

---

## Summary

Add `avoid_repeated_property_aliases` to flag a class that declares two or more public getters/fields that return the exact same underlying value under different names (e.g. `String get userName => name;` alongside `String get displayName => name;` alongside `String get name`) — multiple names for one value create ambiguity about which is "canonical," invite call sites to inconsistently pick different aliases for the same concept, and multiply the surface area that must be kept in sync if the underlying value's computation ever changes.

**Closes gap:** flutter_skill_lints `avoid_repeated_property_aliases`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

When a class exposes the same value under several names, external callers have no principled way to choose between them, and inconsistent usage across the codebase (`user.name` in one file, `user.userName` in another, `user.displayName` in a third) makes future refactors — renaming the concept, changing its computation, deprecating one form — require hunting down every alias rather than one canonical accessor.

---

## Detection / Behavior

Flag a getter/field within a class whose return expression is identical to another getter/field's return expression already declared in the same class (same underlying field reference or identical computed expression), reporting at the later (duplicate) declaration and naming the earlier one as canonical in the correction message.

### Should flag (bad code)

```dart
class UserProfile {
  UserProfile(this.name);

  final String name;

  String get userName => name; // LINT — alias of `name`
  String get displayName => name; // LINT — alias of `name`
}
```

### Should pass (good code)

```dart
class UserProfile {
  UserProfile(this.name);

  final String name; // OK — one canonical accessor
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Pure API-surface-hygiene style rule with no correctness impact; appropriate for a deep code-quality pass rather than default-on.

---

## Edge Cases

1. **Second getter exists specifically for backward compatibility during a rename migration (`@Deprecated('Use name instead') String get userName => name;`)** — should pass; a `@Deprecated`-annotated alias is a deliberate, temporary, and self-documenting migration aid, not an accidental duplicate.
2. **Two getters compute the same value via a different, non-identical expression path (`get area => width * height;` vs. `get size => height * width;`)** — needs discussion; textually different expressions that are mathematically equivalent are much harder to detect reliably and risk false positives on genuinely distinct concepts that happen to compute the same formula — scope detection to exact expression equality (same identifier or identical AST shape) only, leaving semantic-equivalence detection out of scope.
3. **Both accessors are required by two different interfaces the class implements (unavoidable name collision from multiple inheritance of interfaces)** — should pass; the duplication is structurally required, not a code-quality choice the author made.
4. **Getters in different classes (not the same class) that happen to expose the same value under different names** — out of scope; the rule is intentionally scoped to a single class's own API surface, where the choice to add a redundant alias is squarely within the author's control.

---

## Alternatives Considered

- **Detect cross-class duplication project-wide** — rejected; without a shared receiver type, "these two getters return the same value" isn't a coherent single-file/single-class code-quality signal, and would require far more infrastructure (project-wide semantic value tracking) for a rule that is fundamentally about one class's internal consistency.

---

## Decision

---

## Implementation Notes

---

## Commits
