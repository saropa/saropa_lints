# PROPOSAL: Flag Redundant Parentheses in Expressions

**Status: Implemented**

Created: 2026-09-02
Type: New rule
Related rules: `unnecessary_code_rules.dart` family (`AvoidUnnecessaryBlockRule`, `AvoidUnnecessaryCallRule`, etc.)

---

## Summary

Add `avoid_unnecessary_parentheses` — a general stylistic check flagging parenthesized expressions where the parentheses do not change precedence, associativity, or readability (e.g. `(x)`, `(a + b) + c` where `+` is already left-associative and no other operator is present, `return (value);`). This is the general-purpose sibling of the existing `unnecessary_code_rules.dart` family, which already flags unnecessary blocks/calls/constructors but has no rule for unnecessary parentheses in expressions.

**Closes gap:** DCM `avoid-unnecessary-parentheses` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

Redundant parentheses are cosmetic noise that `dart format` does not remove (formatting only re-indents/re-wraps, it does not strip semantically-inert parens), so they accumulate from copy-paste and IDE auto-complete artifacts and never get cleaned up without a dedicated lint. DCM ships `avoid-unnecessary-parentheses` as prior art; it's a pure readability rule with an unambiguous, syntax-only detection rule (no type resolution needed), making it cheap to implement and safe to autofix.

---

## Detection / Behavior

Flag a `ParenthesizedExpression` node whose inner expression, if the parentheses were removed, would parse to the exact same AST shape in its current position — i.e. the parens are not required by operator precedence, are not disambiguating a cascade/conditional, and are not around a single identifier/literal that stylistically never needs wrapping.

### Should flag (bad code)

```dart
void example() {
  final x = (5); // LINT — parens around a literal do nothing
  final y = (a + b); // LINT — no surrounding operator requires this grouping
  return (someValue); // LINT — parens around a return expression with no lower-precedence context
}
```

### Should pass (good code)

```dart
void example() {
  final x = (a + b) * c; // OK — parens required: changes evaluation order vs a + b * c
  final y = -( a + b); // OK — parens required to negate the sum, not just `a`
  final isValid = (a is String) && b; // OK — parens clarify a mixed `is`/`&&` precedence, common style allowance
}
```

---

## Proposed Tier

Tier: Stylistic (opt-in, no default tier)
Justification: This is pure style with zero correctness impact and a real risk of disagreement on "clarifying" parens some teams intentionally keep around mixed-precedence expressions (e.g. `is` + `&&`). It belongs in the opt-in `stylisticRules` set alongside other formatting-adjacent preferences, not forced on any of the five numbered tiers by default.

---

## Edge Cases

1. **Parens required for correct precedence** (`(a + b) * c`) — must never flag; this is the core false-positive risk and the primary implementation hazard.
2. **Parens clarifying mixed `is`/`as`/`&&`/`||` precedence for readability** (a widely-followed style convention even though not strictly required) — should pass; treat as an explicit exception list rather than flagging, since removing these paren groups is a net readability loss even though technically redundant.
3. **Parens around a cascade receiver** (`(objectExpr)..method()`) — should pass if required to disambiguate the cascade target from a lower-precedence context; only flag when genuinely removable.
4. **Parens in a `switch` expression/pattern context** — should discuss; pattern-matching parens can carry different semantics (record patterns) and need careful exclusion from a generic "redundant parens" pass.
5. **Double-wrapped parens** (`((x))`) — should flag the outer pair unconditionally; this is never ambiguous.
6. **Parens required around a function-typed expression before invocation** (`(() => 1)()`) — should pass; required by grammar, not stylistic.

---

## Alternatives Considered

- **Ship in a numbered tier (e.g. Pedantic) instead of Stylistic** — rejected; the "clarifying parens" edge case (#2) is genuinely contested style, closer to `require_trailing_commas`-style opt-in preference than a bug-catcher, so Stylistic (opt-in) is the safer default placement.
- **Detect via `dart format`'s own idempotency (format twice, diff)** — rejected as an implementation strategy; `dart format` does not remove redundant parens at all (confirmed: it only affects whitespace/wrapping), so this approach would not work — a dedicated AST check is required.

---

## Decision

---

## Implementation Notes

---

## Commits
