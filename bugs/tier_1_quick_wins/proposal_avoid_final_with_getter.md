# PROPOSAL: Flag Redundant Custom Getter for a `final` Field of the Same Name

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `avoid_final_with_getter` to flag a class that declares a private `final` field (e.g. `final int _count`) alongside a hand-written public getter of the corresponding name that does nothing but return the field unchanged (e.g. `int get count => _count;`) — this boilerplate is pure noise when the field could simply be made a public `final` field directly, with identical external behavior (read-only, immutable after construction).

**Closes gap:** solid_lints `avoid-final-with-getter`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Dart's `final` fields are already read-only from outside the class — wrapping one in a getter that adds no logic (no computation, no lazy init, no transformation) is Java-era boilerplate that adds a private field, a getter method, and an extra layer of indirection for zero behavioral gain. Removing the wrapper and exposing the field directly as `final` is strictly simpler and equally safe.

---

## Detection / Behavior

Flag a class member getter whose body is a single `return` (or arrow expression) that returns exactly one private `final` field, where that field is not accessed anywhere else via any transformation (i.e. the getter performs no computation).

### Should flag (bad code)

```dart
class User {
  User(this._name);

  final String _name;

  String get name => _name; // LINT — getter adds nothing over a public final field
}
```

### Should pass (good code)

```dart
class User {
  User(this.name);

  final String name; // OK — expose the final field directly
}
```

```dart
class Circle {
  Circle(this._radius);

  final double _radius;

  double get area => 3.14159 * _radius * _radius; // OK — getter computes a derived value
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Pure boilerplate-reduction style rule with no correctness impact; appropriate for a deep code-quality pass rather than default-on tiers.

---

## Edge Cases

1. **Getter is `@override` implementing an interface/abstract class contract** — should pass; the getter is required by the supertype even though its body is trivial.
2. **Getter body does a null-check or default-value fallback (`_name ?? 'Unknown'`)** — should pass; that is a transformation, not a pass-through.
3. **Field is `late final`, not plain `final`** — should flag the same; the immutability characteristic (not the initialization timing) is what makes the wrapper redundant.
4. **Getter is documented with a DartDoc comment (e.g. explaining the public API contract)** — needs discussion; a documented pass-through getter may be intentional API surface design. Consider passing when the getter carries its own DartDoc, since removing it would also remove the documented contract point.

---

## Alternatives Considered

- **Also flag setter+field pairs (`set name(String v) => _name = v;`)** — deferred; setters wrapping a mutable field are a different (more debatable) pattern and out of scope for this rule, which specifically targets `final` immutability boilerplate.

---

## Decision

---

## Implementation Notes

---

## Commits
