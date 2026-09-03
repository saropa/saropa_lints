# PROPOSAL: Flag Functions Exceeding a Lines-of-Code Threshold

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_long_functions` (if extended — check for exact-name collision before implementing as new)

---

## Summary

Add `function_lines_of_code` to flag functions/methods whose body exceeds a configurable line-count threshold — a pure LOC metric, distinct from any existing cyclomatic-complexity or statement-count based long-function rule.

**Closes gap:** `solid_lints` `function_lines_of_code` (LOC-based, distinct from complexity-based long-function detection). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "solid_lints" gaps section, and the "Configuration & metrics" section noting `class_length` (klin_dart, LOC-based) is likewise distinct from saropa's member-count-based `avoid_god_class`.

---

## Motivation

Saropa already has a `bugs/tier_2_high_value/proposal_extend_avoid_long_functions_dcm_parity.md`-adjacent gap around long functions, but per the project's own CLAUDE.md hard limit ("Functions ≤50 lines" self-reviewer enforced), a pure line-count metric is the project's own primary readability signal — cyclomatic complexity and LOC catch different smells (a function can be short but deeply branchy, or long but linear), so both metrics have independent value and `solid_lints` ships LOC as a distinct rule from complexity-based ones.

---

## Detection / Behavior

### Should flag (bad code)

```dart
void processOrder(Order order) {
  // ... 60+ lines of sequential, low-branching logic ...
} // LINT — function body exceeds the configured line-count threshold (e.g. 50 lines); extract helper functions
```

### Should pass (good code)

```dart
void processOrder(Order order) {
  _validateOrder(order);
  _applyDiscounts(order);
  _chargePayment(order);
  _sendConfirmation(order);
} // OK — under threshold, delegates to focused helpers
```

---

## Proposed Tier

Tier: Comprehensive
Justification: style/maintainability metric rather than a correctness bug; a raw threshold has legitimate exceptions (generated builders, large `switch` bodies), so it's placed at deep-review tier rather than Essential/Recommended.

---

## Edge Cases

1. **Function body dominated by a single large `switch`/`if-else` chain with many short cases** — needs discussion; LOC-based counting will flag this even though each branch is trivial — may warrant excluding blank/comment lines from the count, or a higher default threshold than the 50-line CLAUDE.md convention to reduce noise on this shape.
2. **Generated code (`.g.dart`, `.freezed.dart`)** — should pass; standard generated-file suppression applies.
3. **Function with a long parameter/return-type signature but a short body** — should count only body lines, not signature lines, to avoid penalizing verbose typing.
4. **Blank lines and comment-only lines inside the body** — needs discussion; recommend excluding both from the count so refactoring toward well-commented code (per this project's own "always write code comments" hard rule) doesn't get penalized by the same metric that's supposed to reward readability.

---

## Alternatives Considered

- **Reuse/extend an existing long-function rule instead of adding a new one** — rejected only if verification confirms the existing rule is complexity-based, not LOC-based (per the gap analysis's explicit distinction); if saropa's existing rule turns out to already be LOC-based on inspection, this proposal should be converted into an extension rather than a new rule — verify before implementing.

---

## Decision

---

## Implementation Notes

Configurable threshold (default suggestion: 50, matching CLAUDE.md's own functions-≤50-lines convention); exclude blank lines and comment-only lines from the count per edge case above.

---

## Commits
