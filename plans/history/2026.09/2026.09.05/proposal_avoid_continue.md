# PROPOSAL: Flag `continue` Statements as a Readability Smell

**Status: Duplicate — already implemented as `AvoidContinueRule` (`prefer_no_continue_statement`, alias `avoid_continue_statement`) in `lib/src/rules/flow/control_flow_rules.dart`**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_labeled_statements` (sibling rarely-needed-control-flow rule proposed separately)

---

## Summary

Add `avoid_continue` to flag bare `continue;` statements inside loops, recommending an inverted early-`if`
guard (`if (!condition) { ... rest of loop body ... }`) or an extracted helper function instead. `continue`
forces a reader to track "what happens for the rest of this iteration" implicitly, whereas restructuring the
loop body around the skip condition keeps the logic linear and locally readable.

**Closes gap:** `awesome_lints` `avoid_continue` (github.com/LucasXu0/awesome_lints). Implementing this
proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Like `avoid_labeled_statements` (saropa's existing proposal for the sibling `break label;`/`continue label;`
mechanism), a bare `continue;` is a valid but non-local control-flow jump: a reader has to mentally simulate
"skip to next iteration" rather than reading the loop body top-to-bottom. Most `continue` usages can be
rewritten as an inverted guard condition wrapping the rest of the loop body, which reads as ordinary
sequential logic instead of a jump.

---

## Detection / Behavior

### Should flag (bad code)

```dart
for (final user in users) {
  if (!user.isActive) {
    continue; // LINT — avoid_continue: prefer inverting the guard condition
  }
  process(user);
}
```

### Should pass (good code)

```dart
for (final user in users) {
  if (user.isActive) {
    process(user); // OK — same logic, no jump
  }
}
```

---

## Proposed Tier

Tier: Stylistic (opt-in, no default tier)
Justification: Pure control-flow style preference with no correctness implication — matches saropa's
placement for the closely related `avoid_labeled_statements` at Comprehensive; `continue` alone is common
enough and low-risk enough that it should stay opt-in rather than defaulted.

---

## Edge Cases

1. **Multiple `continue` statements guarding different early-skip conditions in the same loop** — should
   still flag each occurrence; rewriting all of them into nested/combined guards is a larger refactor left to
   the developer, not a simple invert-and-wrap quick fix.
2. **`continue` inside a `switch`-in-`for` used to fall through to the next loop iteration** — should flag
   same as any other `continue`; the AST node is the same regardless of surrounding construct.
3. **`continue label;` targeting an outer loop** — should also flag; overlaps with `avoid_labeled_statements`
   but represents the same "non-local jump" smell from the `continue` side specifically.
4. **Generated code (`.g.dart`, `.freezed.dart`)** — should pass; standard generated-file suppression applies.

---

## Alternatives Considered

- **Quick fix that auto-inverts the guard and re-indents the remaining loop body** — deferred; mechanically
  safe for the single-guard case (Edge Case 1's simple form) but risks producing deeply nested code for loops
  with multiple `continue`s, so start as flag-only and consider a fix in a follow-up once real-world false
  positive/negative shape is known.

---

## Decision

---

## Implementation Notes

---

## Commits
