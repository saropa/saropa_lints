# PROPOSAL: Require `super.props` Call When Overriding Equatable/FastEquatable `props` in a Subclass

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `require_equatable_props_completeness` (if present, otherwise `none`)

---

## Summary

Add `always_call_super_props_when_overriding_equatable_props` to flag a class that extends another `Equatable`/`FastEquatable` class (i.e. its superclass is itself `Equatable`-based, not `Object`) and overrides `props` (or `equatableProps`/`props` getter for `FastEquatable`) without including `...super.props` (or the equivalent) in the returned list. Omitting it silently drops the superclass's own equality-relevant fields from the subclass's equality/hashCode computation.

**Closes gap:** `equatable_lint` `always_call_super_props_when_overriding_equatable_props` and `fast_equatable_lint` (equivalent rule) (pub.dev). Implementing this proposal as specified fully closes this competitive gap for both packages — see `plans/GAP_ANALYSIS.md`.

**Package dependency:** Applies when the codebase uses `equatable` (`Equatable`/`EquatableMixin`) and/or `fast_equatable` (`FastEquatable`). Detection should branch on which base class is present; the defect pattern and fix are identical for both.

---

## Motivation

Equality-by-value classes built on `Equatable`/`FastEquatable` frequently form inheritance chains (`abstract class BaseFailure extends Equatable { List<Object?> get props => [code]; }`, then `class NetworkFailure extends BaseFailure { @override List<Object?> get props => [statusCode]; }`). If the subclass's `props` override forgets to include `...super.props`, `code` silently stops participating in equality/hashCode for every `NetworkFailure` instance — two failures with different `code` but the same `statusCode` become "equal," a correctness bug that unit tests comparing by identity/value alone will not catch unless they specifically probe the inherited field. `equatable_lint` and `fast_equatable_lint` both ship this check independently for their respective base classes; saropa_lints should cover both under one rule since the defect shape and fix are identical.

---

## Detection / Behavior

Flag a `props` (or `FastEquatable`'s designated equality-list) getter override in a class whose immediate superclass is itself an `Equatable`/`EquatableMixin`/`FastEquatable` subclass (not a direct `Object`/plain-class supertype), when the getter's returned list literal does not contain a spread of `super.props` (or the `FastEquatable` equivalent member name).

### Should flag (bad code)

```dart
abstract class BaseFailure extends Equatable {
  const BaseFailure(this.code);
  final int code;

  @override
  List<Object?> get props => [code];
}

class NetworkFailure extends BaseFailure {
  const NetworkFailure(super.code, this.statusCode);
  final int statusCode;

  @override
  List<Object?> get props => [statusCode]; // LINT — drops inherited `code` from equality
}
```

### Should pass (good code)

```dart
class NetworkFailure extends BaseFailure {
  const NetworkFailure(super.code, this.statusCode);
  final int statusCode;

  @override
  List<Object?> get props => [statusCode, ...super.props]; // OK — inherited fields preserved
}
```

---

## Proposed Tier

Tier: Recommended
Justification: Silent correctness bug (equality/hashCode) in a very common inheritance pattern; mechanical to detect and mechanical to fix (`...super.props` insertion).

---

## Edge Cases

1. **Direct subclass of `Equatable`/`FastEquatable` itself (no intermediate `Equatable` superclass)** — should pass; there is no `super.props` to call since the immediate superclass is the base library class, not another equatable subclass.
2. **Superclass's `props` is intentionally empty** (`List<Object?> get props => [];`) — should still flag per the mechanical rule (missing `...super.props`), since a future edit to the superclass adding fields would otherwise silently bypass the subclass; correction message can note the spread is a no-op today but future-proofs the subclass.
3. **Subclass includes `super.props` but not as a spread** (e.g. manually re-lists the same fields instead of spreading) — should flag; the rule specifically checks for the `...super.props` spread token, not equivalent-but-manual duplication, since manual duplication drifts when the superclass's fields change.
4. **`FastEquatable`'s member is not literally named `props`** — detection must resolve the actual member name from the `fast_equatable` package's API (verify exact getter name during implementation) rather than assuming parity with `Equatable`.

---

## Alternatives Considered

- **Ship as two separate rules, one per package** — rejected per task instructions; the defect pattern, detection logic, and fix are identical modulo the base-class name, so one rule with dual-package detection avoids duplicating ~95% of the implementation.

---

## Decision

---

## Implementation Notes

---

## Commits
