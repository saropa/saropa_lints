# PROPOSAL: Do Not Add `avoid_catch_error` — Conflicts With `prefer_then_catcherror`

**Status: Declined**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_then_catcherror` (saropa's existing rule recommends the opposite)

---

## Summary

`leancode_lint`'s `avoid_catch_error` flags `Future.catchError()` usage and recommends `try`/`catch` around
`await` instead. saropa already ships `prefer_then_catcherror`, which recommends the opposite for
non-awaited future chains: use `.then(...).catchError(...)` over a bare unhandled future or an awkward
wrapper.

**Closes gap:** `leancode_lint` `avoid_catch_error` (github.com/leancodepl/flutter_corelibrary). This gap is
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

- **Scope `avoid_catch_error` to only awaited futures**, leaving `.then().catchError()` alone for
  fire-and-forget chains — considered as a narrower rule that might coexist with `prefer_then_catcherror`.
  Rejected for this pass: the two source rules cover the same API surface (`catchError`) with opposite
  defaults, and narrowing the scope well enough to avoid contradicting the existing rule needs a design
  decision, not a mechanical port. Revisit as a fresh, narrowly-scoped proposal if a concrete false-negative
  from `prefer_then_catcherror` is found in practice.

---

## Decision

Declined. Direct philosophical conflict with saropa's existing `prefer_then_catcherror`, which recommends
`.then().catchError()` for the same `catchError()` API this rule flags as a defect. Per
`plans/GAP_ANALYSIS.md` "leancode_lint" Gaps section, this was identified as a same-topic-opposite-
recommendation case, not a genuine coverage gap.

---

## Implementation Notes

None — not implemented.

---

## Commits
