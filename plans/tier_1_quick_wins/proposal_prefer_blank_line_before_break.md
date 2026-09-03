# PROPOSAL: Blank Line Before `break` Statement

**Status: Implemented**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_blank_line_before_case`, `prefer_blank_line_before_constructor`, `prefer_blank_line_before_method`, `prefer_blank_line_before_return` (sibling stylistic blank-line-before-X family, all in `lib/src/rules/stylistic/formatting_rules.dart`)

---

## Summary

Add a stylistic rule that warns when a `break` statement is not preceded by a blank line, following the exact pattern already established by the sibling `prefer_blank_line_before_case`/`_constructor`/`_method`/`_return` rules.

**Closes gap:** DCM `newline-before-break` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

saropa_lints already has a well-established family of "blank line before X" opt-in stylistic rules in `lib/src/rules/stylistic/formatting_rules.dart` — `prefer_blank_line_before_case`, `prefer_blank_line_before_constructor`, `prefer_blank_line_before_method`, `prefer_blank_line_before_return`, and `prefer_blank_line_before_else`. Each targets a different control-flow or declaration keyword and shares the same implementation shape: `LintImpact.info`, `RuleType.codeSmell`, `{'convention'}` tags, `RuleCost.medium`, and the shared `AddBlankLineBeforeFix` quick fix. `break` is conspicuously the one common loop/switch-exit keyword missing from this family — DCM (dcm.dev) ships the equivalent as `newline-before-break`, applying the same visual-separation rationale saropa already documents for `case`/`return`/`else`: a blank line before a control-flow-exiting statement visually marks the exit point and separates it from the logic that led to it, particularly useful in longer `switch` cases or loop bodies with several statements before the `break`.

---

## Detection / Behavior

### Should flag (bad code)

```dart
switch (x) {
  case 1:
    doSomething();
    break;  // LINT — no blank line before break
  case 2:
    doSomethingElse();

    break;  // OK — blank line present
}
```

### Should pass (good code)

```dart
switch (x) {
  case 1:
    doSomething();

    break;
  case 2:
    doSomethingElse();

    break;
}

// Also OK: break is the only/first statement in its block (nothing to
// separate from), same exemption pattern as prefer_blank_line_before_return
// skipping index <= 0.
for (final item in items) {
  break;
}
```

---

## Proposed Tier

Tier: Stylistic (opt-in, no default tier) — matching every sibling rule in this family (`prefer_blank_line_before_case`, `_constructor`, `_method`, `_return`, `_else` are all documented "Stylistic rule (opt-in only). No performance or correctness benefit.").
Justification: this is a pure formatting preference with zero behavioral impact; the entire `prefer_blank_line_before_*` family is deliberately opt-in via the stylistic tier rather than any of the five progressive tiers, and this rule should follow the identical placement for consistency.

---

## Edge Cases

1. **`break` as the first statement in its enclosing block** — should NOT flag, mirroring `NewlineBeforeReturnRule`'s explicit `if (index <= 0) return;` guard: there is no preceding statement to separate from.
2. **`break` immediately following a `case`/`default` label with no other statements** (fall-through-avoidance idiom, `case 1: break;`) — should NOT flag; a single-statement case body has nothing to separate, matching the spirit of `NewlineBeforeCaseRule`'s `if (previous.statements.isEmpty) continue;` skip for empty fall-throughs.
3. **Labeled `break label;` inside nested loops** — the rule should treat a labeled break identically to a bare `break`; the label does not change the statement's role as a control-flow exit needing the same visual separation.

---

## Alternatives Considered

- **Folding into a single generic "blank line before control-flow-exit statement" rule covering `break`/`continue`/`throw`/`return` together** — rejected in favor of matching DCM's granularity (separate `newline-before-break`, `newline-before-continue`, `newline-before-throw` rules) and saropa's own existing precedent of one rule per keyword (`prefer_blank_line_before_case` vs. `_constructor` vs. `_method` are already separate despite sharing nearly identical bodies). Keeping them separate lets a team enable blank-line-before-throw without also requiring it before every break in dense switch statements, which is a real style split teams request independently.

---

## Decision

---

## Implementation Notes

Can reuse `AddBlankLineBeforeFix` as the quick fix generator, and the same `Block`/`SwitchMember`-walking line-comparison logic already present in `NewlineBeforeReturnRule`/`NewlineBeforeCaseRule` — register via `context.addBreakStatement` and look up the enclosing `Block` or `SwitchMember.statements` list to find the previous sibling statement.

---

## Commits
