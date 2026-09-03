# PROPOSAL: Flag Calling Equatable's Own Equality Members on `this`/`super` Incorrectly

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `require_equatable_props_override`, `list_all_equatable_fields`, `avoid_mutable_field_in_equatable`

---

## Summary

Flag a class that extends `Equatable` (or mixes in `EquatableMixin`) but calls `super.props`, `super ==`, or `super.hashCode` incorrectly within its own equality-related overrides — specifically, referencing the base class's equality machinery in a way that bypasses or double-applies Equatable's own generated behavior instead of relying on the framework contract (`props` alone).

**Closes gap:** DCM `avoid-equatable-call-on-equality-base-class` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

Equatable's entire value proposition is that subclasses never need to write their own `==`/`hashCode`/`props`-combining logic — they declare `props` and Equatable's base class handles the rest. A subclass that manually calls `super.hashCode`, `super ==`, or otherwise reaches into the equality base class from inside its own overridden equality members reintroduces exactly the boilerplate-and-bug-risk Equatable exists to eliminate (mixing manually-combined hash codes with Equatable's own `Object.hashAll(props)`-based one, for instance, can silently produce an inconsistent, non-deterministic hash). saropa_lints already has several Equatable correctness rules (`require_equatable_props_override`, `list_all_equatable_fields`, `avoid_mutable_field_in_equatable`) in `lib/src/rules/packages/equatable_rules.dart`, but none currently checks base-class equality call misuse (confirmed by grep — zero matches for `avoid_equatable_call_on_equality_base_class` in `lib/src/rules/`).

---

## Detection / Behavior

### Should flag (bad code)

```dart
class Money extends Equatable {
  final int cents;
  const Money(this.cents);

  @override
  List<Object?> get props => [cents];

  @override
  int get hashCode => super.hashCode ^ cents.hashCode; // LINT — manually re-combining with Equatable's own hashCode
}
```

```dart
class Point extends Equatable {
  final int x;
  final int y;
  const Point(this.x, this.y);

  @override
  List<Object?> get props => [x, y];

  @override
  bool operator ==(Object other) =>
      super == other && x == (other as Point).x; // LINT — calling super == and re-implementing comparison
}
```

### Should pass (good code)

```dart
class Money extends Equatable {
  final int cents;
  const Money(this.cents);

  @override
  List<Object?> get props => [cents]; // OK — hashCode/== inherited from Equatable, no manual override
}
```

```dart
class Point extends Equatable {
  final int x;
  final int y;
  const Point(this.x, this.y);

  @override
  List<Object?> get props => [x, y]; // OK — equality fully delegated to Equatable via props
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: This is a narrow, correctness-adjacent misuse pattern (manually touching a base class's equality machinery that's meant to be fully delegated) — it can produce real hash-inconsistency bugs, but it's rare enough in practice (most misuse of Equatable is a missing `props` entry, already covered by `list_all_equatable_fields` at a higher tier) that Comprehensive is the appropriate default rather than Essential/Recommended.

---

## Edge Cases

1. **A class overriding `hashCode`/`==` for a deliberate reason unrelated to Equatable (e.g. combining Equatable's identity with an external cache key)** — needs discussion; the rule should only fire when the class extends `Equatable`/mixes in `EquatableMixin` AND declares its own `hashCode`/`==` override that references `super`, since that combination is specifically what breaks Equatable's guarantee. A class not extending Equatable is out of scope entirely.
2. **Calling `super.props` (not `super.hashCode`/`super ==`) from within a subclass's own `props` getter to extend a parent's props list** — should pass; this is Equatable's own documented pattern for props inheritance across an Equatable subclass hierarchy (e.g. `List<Object?> get props => [...super.props, extraField]`) and must not be flagged, since it's the *correct* way to compose props across levels.
3. **Class overrides only `toString()` and calls `super.toString()`** — should pass; `toString()` is not part of Equatable's equality contract (that's `stringify`), so calls to it are unrelated to this rule's scope.
4. **`EquatableMixin` used instead of `extends Equatable`** — should still flag using the same detection, since the mixin provides the identical `hashCode`/`==`/`props` contract that a manual override would break.

---

## Alternatives Considered

- **Blanket-ban any override of `hashCode`/`==`/`props` in an Equatable subclass** — rejected as too broad; the correct and required override is `props` itself (enforced by `require_equatable_props_override`), so a blanket ban would conflict with that existing rule. This proposal targets specifically `hashCode`/`==` overrides that call into `super`'s equality machinery, not `props` overrides.
- **Detect via string matching on `super.hashCode`/`super ==` tokens** — rejected per saropa's own conventions ("Type checking over string matching," `bugs/ISSUE_REPORT_GUIDE.md` Common Pitfalls table); implementation should resolve `SuperExpression` targets and `PropertyAccess`/`BinaryExpression` (`==`) nodes via the AST, matching the existing `isEquatable()` helper's pattern of checking `ExtendsClause`/`WithClause` rather than text matching.
