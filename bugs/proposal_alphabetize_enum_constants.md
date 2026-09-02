# PROPOSAL: Alphabetize Enum Constant Declaration Order

**Status: Declined**

Created: 2026-09-02
Type: New rule (philosophical conflict)
Related rules: `none`

---

## Summary

`essential_lints` ships `alphabetize_enum_constants`, requiring enum values to be declared in alphabetical order. saropa_lints declines to adopt this rule: enum constant order frequently carries deliberate meaning in saropa codebases (severity/priority ladders, state-machine transition order, tier progression) that alphabetizing would destroy or obscure.

**Closes gap:** `essential_lints` `alphabetize_enum_constants` (pub.dev). This gap is intentionally NOT closed — see Decision below.

---

## Motivation

Many enums encode an implicit ordinal meaning through declaration order — `enum LintImpact { critical, high, medium, low }` reads as a severity ladder; `enum Tier { essential, recommended, professional, comprehensive, pedantic }` (saropa's own tier system) is a progression, not an alphabet. `.index` comparisons and `compareTo`-style logic in real code frequently depend on this declared order. Forcing alphabetical order would silently invert or scramble that meaning for a purely cosmetic naming-sort benefit, and would conflict with saropa's own `Tier` enum today.

---

## Detection / Behavior

Not implemented — rule declined.

---

## Proposed Tier

N/A — declined.

---

## Edge Cases

N/A — declined.

---

## Alternatives Considered

- **Apply only to enums with no `.index`-dependent logic and no doc comment implying order** — rejected; reliably proving "no dependence on order" statically is not feasible (index usage can be indirect via `List<T>.indexOf` comparisons, switch fallthrough order, or external serialization contracts), so any heuristic would either miss real order-dependent enums (false negative → data/logic bug) or be too narrow to be worth shipping.

---

## Decision

Declined. Enum declaration order is semantically load-bearing in saropa's own codebase (tiers, severities, impact levels). A rule that forces alphabetical order would actively fight against `lib/src/tiers.dart`-style enums and risk masking real ordinal bugs behind a "looks tidy" alphabetical pass. See `feedback_understand_before_questioning_architecture.md`.

---

## Implementation Notes

N/A — declined.

---

## Commits
