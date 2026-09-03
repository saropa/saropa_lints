# PROPOSAL: Blank Line Before `continue` Statement

**Status: Implemented**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_blank_line_before_case`, `prefer_blank_line_before_constructor`, `prefer_blank_line_before_method`, `prefer_blank_line_before_return`, and the sibling `proposal_prefer_blank_line_before_break.md` (same family)

---

## Summary

Add a stylistic rule that warns when a `continue` statement is not preceded by a blank line, following the same pattern as the existing `prefer_blank_line_before_case`/`_constructor`/`_method`/`_return` family in `lib/src/rules/stylistic/formatting_rules.dart`.

**Closes gap:** DCM `newline-before-continue` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

Companion gap to `proposal_prefer_blank_line_before_break.md`: DCM (dcm.dev) ships both `newline-before-break` and `newline-before-continue` as separate rules with identical rationale — a blank line before a loop-control-exit statement visually marks it as an early-exit point in a loop body, distinguishing it from ordinary sequential statements. saropa's existing `prefer_blank_line_before_*` family covers `case`, `constructor`, `method`, `return`, and `else`, but has no rule for `continue`, leaving loop bodies with a `continue` guard buried mid-block indistinguishable from ordinary logic at a glance — exactly the readability problem the sibling rules in this family already solve for `return`/`break`.

---

## Detection / Behavior

### Should flag (bad code)

```dart
for (final item in items) {
  if (item.isInvalid) {
    log('skipping invalid item');
    continue;  // LINT — no blank line before continue
  }
  process(item);
}
```

### Should pass (good code)

```dart
for (final item in items) {
  if (item.isInvalid) {
    log('skipping invalid item');

    continue;  // OK — blank line present
  }
  process(item);
}

// Also OK: continue is the only statement in its block.
for (final item in items) {
  if (item.isInvalid) continue;
}
```

---

## Proposed Tier

Tier: Stylistic (opt-in, no default tier) — matching the sibling `prefer_blank_line_before_*` family placement.
Justification: pure formatting preference, zero behavioral or correctness impact, consistent with every other rule in this family being opt-in-only under the stylistic tier rather than any progressive tier.

---

## Edge Cases

1. **`continue` as the sole statement in a single-line guard `if (cond) continue;`** — should NOT flag; there is no preceding sibling statement inside the (implicit or explicit) block to separate from, mirroring the `index <= 0` guard in `NewlineBeforeReturnRule`.
2. **Labeled `continue label;` in nested loops** — treat identically to a bare `continue`; the label does not change its role as a loop-control-exit needing the same visual marker.
3. **`continue` inside a `for`/`while`/`do-while` body vs. inside a `switch` case nested in a loop** — the rule should look at the immediately enclosing `Block`'s statement list regardless of which loop or switch construct contains it, matching how `NewlineBeforeReturnRule` only cares about the immediate `Block` parent, not the outer control-flow kind.

---

## Alternatives Considered

- **A single combined rule for `break`+`continue`+`throw`** — rejected for the same reasons documented in `proposal_prefer_blank_line_before_break.md`'s Alternatives section: DCM ships these as three separate rules, and saropa's existing family already treats each keyword as an independently toggleable rule rather than a single opinionated bundle.

---

## Decision

---

## Implementation Notes

Shares the same `AddBlankLineBeforeFix` quick fix and `Block`-statement-list line-comparison approach as the sibling `prefer_blank_line_before_break` proposal — register via `context.addContinueStatement`.

---

## Commits
