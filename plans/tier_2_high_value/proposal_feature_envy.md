# PROPOSAL: Flag Methods That Use Another Class's Members More Than Their Own

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_god_class` (related code-smell family, different metric)

---

## Summary

Add `feature_envy` to flag a method that accesses members (fields/methods) of another class more frequently than it accesses members of its own enclosing class — the classic "feature envy" code smell, indicating the method's logic probably belongs on the other class instead.

**Closes gap:** `solid_lints` `feature_envy`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "solid_lints" gaps section.

---

## Motivation

A method that repeatedly reaches into another object's data to do its work — rather than asking that object to do the work — violates the "tell, don't ask" principle and signals the method is misplaced. This is a well-established OO design smell (Fowler) that saropa currently has no direct detector for; `avoid_god_class` catches an oversized class, not a method that's outgrown its home class.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class InvoicePrinter {
  String format(Order order) {
    // LINT — method accesses Order's members far more than InvoicePrinter's own state; belongs on Order
    return '${order.customerName}: ${order.items.length} items, total ${order.total}';
  }
}
```

### Should pass (good code)

```dart
class Order {
  String describe() {
    return '$customerName: ${items.length} items, total $total'; // OK — logic lives with the data it uses
  }
}

class InvoicePrinter {
  String format(Order order) => order.describe(); // OK — delegates instead of reaching in
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: subjective code-smell heuristic with meaningful false-positive risk (e.g. legitimate mappers/formatters/visitors), so placed at the deep-review tier rather than Essential/Recommended.

---

## Edge Cases

1. **Explicit mapper/converter classes (`OrderToDtoMapper`) whose entire purpose is to read another class's fields** — should pass; this pattern is exempt by design since "envy" is the class's job. Detect via naming convention (`*Mapper`, `*Converter`, `*Formatter`) or an allowlist.
2. **Method that accesses two or more foreign classes roughly equally, none dominating** — should pass; feature envy requires a single dominant foreign class, not diffuse foreign access.
3. **Static utility/extension methods that inherently only operate on a passed-in parameter (`extension OrderX on Order`)** — should pass; extension methods are explicitly designed to add behavior to a foreign type, not misplaced logic.
4. **Method accessing inherited members from its own superclass, counted as foreign or local?** — should count as local/own-class access, not foreign, since inherited members are part of the method's own type hierarchy.

---

## Alternatives Considered

- **Pure ratio threshold (e.g. foreign-access-count > own-access-count) with no exemptions** — rejected as too blunt; would generate excessive noise on mapper/formatter/visitor classes that are supposed to look this way, so naming-convention/annotation exemptions are necessary from the start.

---

## Decision

---

## Implementation Notes

Requires counting member-access expressions (`.field`, `.method()`) per receiver type within a method body and comparing "self" (this/enclosing class) counts vs. the dominant foreign type's count; needs a configurable threshold and exemption list for known idiomatic patterns (mappers, extensions).

---

## Commits
