# PROPOSAL: Blank Line Before `throw` Statement

**Status: Implemented**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_blank_line_before_return` (closest sibling — same "exit statement" rationale), `prefer_blank_line_before_case`/`_constructor`/`_method`, and the sibling `proposal_prefer_blank_line_before_break.md`/`proposal_prefer_blank_line_before_continue.md`

---

## Summary

Add a stylistic rule that warns when a `throw` statement is not preceded by a blank line, matching the existing `NewlineBeforeReturnRule` implementation pattern in `lib/src/rules/stylistic/formatting_rules.dart` almost exactly (`throw` and `return` are both function/block-exiting statements with identical visual-separation rationale).

**Closes gap:** DCM `newline-before-throw` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

saropa's `prefer_blank_line_before_return` rule (`lib/src/rules/stylistic/formatting_rules.dart:383`, `NewlineBeforeReturnRule`) already documents the exact rationale this rule needs: "Adding a blank line before return statements can improve readability by visually separating the return from the preceding logic." A `throw` statement is structurally identical to a `return` for this purpose — both are the final, block-exiting statement in a function or branch, and both benefit equally from a visual separator marking "this is where control leaves." DCM (dcm.dev) ships this as `newline-before-throw`, and saropa currently has no rule that even inspects blank-line spacing around a bare `throw` statement (the existing `prefer_constructor_body_assignment`/error-handling rules validate `throw` semantics, not spacing).

---

## Detection / Behavior

### Should flag (bad code)

```dart
String parseId(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError('id cannot be empty');  // LINT — no blank line before throw
  }
  return trimmed;
}
```

### Should pass (good code)

```dart
String parseId(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {

    throw ArgumentError('id cannot be empty');  // OK — blank line present
  }
  return trimmed;
}

// Also OK: throw is the first/only statement in its block.
void validate(bool ok) {
  if (!ok) throw StateError('invalid');
}
```

---

## Proposed Tier

Tier: Stylistic (opt-in, no default tier) — matching `prefer_blank_line_before_return` and the rest of the family.
Justification: pure formatting preference; `prefer_blank_line_before_return`, its closest structural sibling, is already documented as "Stylistic rule (opt-in only). No performance or correctness benefit." — this rule should be placed identically for consistency and because a team enabling one exit-statement blank-line rule commonly wants the others toggleable independently (see the Alternatives section on why these stay separate rules).

---

## Edge Cases

1. **`throw` as the sole/first statement in its block** — should NOT flag, reusing `NewlineBeforeReturnRule`'s exact `if (index <= 0) return;` guard: a single-statement guard clause (`if (!ok) throw StateError('invalid');` as a block body, or a one-line block) has nothing preceding to separate from.
2. **`rethrow` vs. `throw`** — `rethrow` is a distinct AST node (`RethrowExpression`, always wrapped in an `ExpressionStatement`, not a `ThrowStatement`). Decide explicitly whether `rethrow` should be included under the same rule (DCM's `newline-before-throw` scope should be checked) or left out — a `rethrow` inside a `catch` block after a logging statement has the same visual-separation argument, so including it is the more consistent default, implemented via a second `context.addExpressionStatement` check filtered to `RethrowExpression`.
3. **`throw` as an expression (not a statement) inside a ternary or `??` chain** — e.g. `final x = value ?? (throw StateError('required'));`. This is a `ThrowExpression`, not a `ThrowStatement`/block-level statement, and has no "preceding sibling statement" to compare against; the rule should only visit block-level `throw` statements (matching `return`'s scope) and explicitly not attempt to flag inline throw-expressions.

---

## Alternatives Considered

- **Extending `NewlineBeforeReturnRule` itself to also visit `ThrowStatement`** — rejected because it would silently change an existing rule's scope for any project that already has `prefer_blank_line_before_return` enabled, potentially surfacing new diagnostics on `throw` statements a team never opted into checking. A separate `prefer_blank_line_before_throw` rule keeps the opt-in boundary explicit, matching DCM's own choice to ship these as separate rule IDs.

---

## Decision

---

## Implementation Notes

Nearly a direct copy of `NewlineBeforeReturnRule`'s `runWithReporter` body with `ReturnStatement`/`context.addReturnStatement` swapped for `ThrowStatement`/`context.addThrowStatement`; can share `AddBlankLineBeforeFix` (or the analogous return-specific fix's non-return-specific logic, since `throw` needs no `AddBlankLineBeforeReturnFix`-style special casing).

---

## Commits
