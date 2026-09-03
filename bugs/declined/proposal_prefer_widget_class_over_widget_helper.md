# PROPOSAL: Declined — Conflicts with Saropa's `prefer_widget_methods_over_classes`

**Status: Declined**

Created: 2026-09-02
Type: New rule (declined)
Related rules: `prefer_widget_methods_over_classes`

---

## Summary

flutter_best_practices_lints ships `prefer_widget_class_over_widget_helper`, which flags private `_build*` methods returning `Widget` and recommends extracting them into their own `Widget` subclass. saropa_lints already ships the opposite rule, `prefer_widget_methods_over_classes`, which flags simple widget classes with a short `build` method and recommends inlining them as a method on the parent instead.

**Closes gap:** flutter_best_practices_lints `prefer_widget_class_over_widget_helper`. This is a documented philosophical conflict, not an absence — see `plans/GAP_ANALYSIS.md` flutter_best_practices_lints Gaps section.

---

## Motivation

Both are real, actively-debated Flutter performance/readability trade-offs: widget-classes get their own `Element`/`BuildContext` and participate in `const`-ness and independent `shouldRebuild` checks (the case for extracting a class), while `_build*` helper methods avoid the boilerplate of a new class and give direct access to the parent's fields/state without threading parameters (the case saropa's existing rule makes). There is no universally-correct answer — it depends on whether the extracted widget benefits from independent rebuild scoping.

saropa has already taken a considered position via `prefer_widget_methods_over_classes` (see MEMORY.md: "Understand architecture before questioning it" — this exact class of decision has been reviewed before). Adding the opposite rule would produce two rules that recommend contradictory refactors for the same code shape.

---

## Detection / Behavior

Not applicable — declined.

---

## Proposed Tier

Not applicable — declined.

---

## Edge Cases

Not applicable — declined.

---

## Alternatives Considered

- **Ship both, mutually exclusive** — rejected for the same reason as `prefer_async_callback`: no tier-level "pick one" mechanism, and the two rules would actively contradict each other for the same code shape.
- **Narrow saropa's existing rule to exclude cases where the helper method captures many parent fields (favoring the class extraction in that case)** — a legitimate refinement of `prefer_widget_methods_over_classes`, but that is a change to the existing rule's heuristics, not a new rule; track separately if pursued.

---

## Decision

Declined. saropa_lints already takes the opposite, deliberate position via `prefer_widget_methods_over_classes`. No new rule.

---

## Implementation Notes

None — no code change.

---

## Commits
