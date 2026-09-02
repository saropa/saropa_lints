# PROPOSAL: Do Not Add `avoid_adjacent_strings` — Conflicts With `prefer_adjacent_strings`

**Status: Declined**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_adjacent_strings` (saropa's existing rule recommends the opposite style)

---

## Summary

`awesome_lints`' `avoid_adjacent_strings` flags Dart's implicit string-literal concatenation
(`'foo' 'bar'` juxtaposed with no operator) and recommends explicit `+` concatenation or interpolation
instead. saropa already ships `prefer_adjacent_strings`, which recommends the opposite: use adjacent-string
juxtaposition over `+` concatenation for compile-time-constant string building.

**Closes gap:** `awesome_lints` `avoid_adjacent_strings` (github.com/LucasXu0/awesome_lints). This gap is
intentionally NOT closed — see Decision below.

---

## Motivation

n/a — declined due to direct conflict with an existing shipped rule.

---

## Detection / Behavior

n/a.

---

## Proposed Tier

n/a.

---

## Edge Cases

n/a.

---

## Alternatives Considered

- **Ship both rules, mutually exclusive via tier/config** — rejected; a lint package taking both sides of the
  same style question (one rule says "always use adjacent strings", another says "never use adjacent
  strings") is confusing and self-contradictory even if only one is enabled by default. Per
  `feedback_understand_before_questioning_architecture` memory guidance, the existing `prefer_adjacent_strings`
  rule was adopted deliberately; adding its inverse should not happen without a documented reason to reverse
  that decision, which none of the source material supplies.

---

## Decision

Declined. Direct philosophical conflict with saropa's existing `prefer_adjacent_strings`, which recommends
implicit string-literal juxtaposition (`'foo' 'bar'`) for compile-time constant concatenation — the exact
pattern `avoid_adjacent_strings` flags as a defect. Per `plans/GAP_ANALYSIS.md` "awesome_lints" Gaps section,
this was identified as a same-topic-opposite-recommendation case, not a genuine coverage gap.

---

## Implementation Notes

None — not implemented.

---

## Commits
