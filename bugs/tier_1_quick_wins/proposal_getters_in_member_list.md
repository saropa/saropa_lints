# PROPOSAL: Flag Getters Declared Outside the Class Member List Grouping

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `getters_in_member_list` to flag a getter (`Type get name => ...`) that is declared scattered among unrelated members (methods, overrides) instead of grouped with the class's fields/computed-property section. Enforces a consistent, navigable member ordering: fields, then getters/setters, then constructors/methods.

**Closes gap:** `essential_lints` `getters_in_member_list` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Classes that mix data-shape members (fields, getters, setters) freely among behavior members (methods) force readers to scan the whole class body to find "what does this object look like" versus "what does it do." Grouping getters with the other property-shaped members near the top of the class keeps the public data contract scannable in one place, independent of when each member was added.

---

## Detection / Behavior

Flag a `MethodDeclaration` with `isGetter == true` whose position in the class member list is separated from the class's field declarations and other getters/setters by one or more method declarations (i.e. a getter appears *after* at least one regular method, when fields/getters exist earlier that it could have been grouped with).

### Should flag (bad code)

```dart
class Order {
  final List<Item> items;

  Order(this.items);

  void addItem(Item item) {
    items.add(item);
  }

  double get total => items.fold(0, (sum, i) => sum + i.price); // LINT — getter declared after a method
}
```

### Should pass (good code)

```dart
class Order {
  final List<Item> items;

  double get total => items.fold(0, (sum, i) => sum + i.price); // OK — grouped with fields

  Order(this.items);

  void addItem(Item item) {
    items.add(item);
  }
}
```

---

## Proposed Tier

Tier: Pedantic
Justification: Pure member-ordering convention with no correctness impact; opt-in style enforcement only.

---

## Edge Cases

1. **Single getter, no methods before it** — should pass; nothing to reorder against.
2. **Getter that overrides an interface member (`@override`)** — needs discussion; overrides are often kept near other overrides rather than the field block, so consider exempting `@override` getters.
3. **Extension methods / mixins** — should apply the same grouping rule within the extension/mixin body.
4. **Getter defined via arrow body vs block body** — both should flag identically; body syntax is irrelevant to placement.

---

## Alternatives Considered

- **Full member-ordering rule (fields → constructors → getters/setters → methods)** — deferred; broader ordering enforcement is a larger rule (`members_ordering`-style) and risks conflicting with existing style rules already in saropa_lints. This proposal scopes to getters only, matching the source package.

---

## Decision

---

## Implementation Notes

---

## Commits
