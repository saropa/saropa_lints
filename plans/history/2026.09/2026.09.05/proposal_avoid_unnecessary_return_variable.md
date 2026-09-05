# PROPOSAL: `avoid_unnecessary_return_variable` — Flag a Variable Assigned Once Then Immediately Returned

**Status: Duplicate** — already exists as `prefer_immediate_return` in `return_rules.dart`. The proposal's own analysis confirms this.

Created: 2026-09-02
Type: New rule
Related rules: `prefer_immediate_return` (near-duplicate — see Alternatives Considered)

---

## Summary

Flag a local variable that is declared and assigned exactly once, then returned as the very next statement, with no other use in between — `final result = compute(); return result;` should collapse to `return compute();`.

**Closes gap:** `solid_lints` `avoid_unnecessary_return_variable` (github.com/solid-software/solid_lints). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` solid_lints "Gaps" section.

---

## Motivation

The intermediate variable adds a line and a name to track without adding any information — the variable is never inspected, logged, or reused before the function exits, so it exists purely as an unnecessary hop between the computed value and the `return`. Both forms compile to the same result; the direct form is one line shorter and removes a throwaway name from the reader's working set. `solid_lints` ships this as a standalone style rule.

**IMPORTANT FINDING — this proposal substantially duplicates an existing saropa rule.** `PreferImmediateReturnRule` (`lib/src/rules/flow/return_rules.dart:361`, code `prefer_immediate_return`) already implements exactly this detection: it inspects the last two statements of a `Block`, checks that the second-to-last is a single-variable `VariableDeclarationStatement` with an initializer, checks the last is a `ReturnStatement` returning a bare `SimpleIdentifier`, and confirms the names match. That is the identical AST shape solid_lints describes for `avoid_unnecessary_return_variable`. `prefer_immediate_return` even ships a working quick fix (`InlineImmediateReturnFix`). See Alternatives Considered before treating this as a genuine gap to build.

---

## Detection / Behavior

### Should flag (bad code)

```dart
String getName() {
  final name = computeName();
  return name; // LINT — declared once, used once, immediately returned
}
```

### Should pass (good code)

```dart
String getName() {
  return computeName();
}

// Also OK — variable is used before the return, so it is not "unnecessary".
String getFormattedName() {
  final name = computeName();
  log('resolved name: $name');
  return name;
}
```

---

## Proposed Tier

Tier: Stylistic (opt-in)
Justification: This is a pure readability preference with zero behavioral or compiled-output difference — matches how `prefer_immediate_return` is already positioned (`LintImpact.info`, enabled via the stylistic tier per its own problem message).

---

## Edge Cases

1. **Variable used between declaration and return** (e.g. passed to a logger, checked in an `if`, or reassigned) — should pass; the variable carries information beyond the return, so collapsing it would lose that.
2. **Multiple variables declared in the same `final a = 1, b = 2;` statement** — should pass; `prefer_immediate_return`'s existing implementation already requires exactly one variable in the declaration list, avoiding ambiguity about which one is "the" returned value.
3. **The returned identifier does not match the just-declared variable name** (shadowing, wrong variable) — should pass; only exact name match between the declaration and the returned identifier qualifies.
4. **Async functions returning a `Future`-typed variable** (`final result = await compute(); return result;`) — should flag same as sync; the pattern and the fix (`return await compute();` or dropping `await` per return-type rules) both apply identically.
5. **Declaration and return separated by a comment-only "statement"** — comments are not AST statements, so the two nodes remain adjacent in the `Block.statements` list; should still flag.

---

## Alternatives Considered

- **Build this as a genuinely new rule** — rejected. Confirmed by reading `lib/src/rules/flow/return_rules.dart:361-440` that `PreferImmediateReturnRule` (`prefer_immediate_return`) already detects this exact pattern (adjacent `VariableDeclarationStatement` + `ReturnStatement` returning the same `SimpleIdentifier`), already ships a quick fix, and is already documented with the identical bad/good example pair solid_lints uses. `plans/GAP_ANALYSIS.md` lists `avoid_unnecessary_return_variable` as a solid_lints GAP, but that appears to be a naming-collision miss in the audit (same class of miss the doc already flags elsewhere for `avoid_returning_widgets` and `avoid_similar_names` — different package, same "check actual behavior before trusting the rule name" lesson).
- **Rename/re-alias `prefer_immediate_return` to also answer as `avoid_unnecessary_return_variable`** — plausible low-cost option if closing the gap-tracking line item in `GAP_ANALYSIS.md` matters more than adding code; the rule already supports config aliases elsewhere in the codebase (see `BannedUsageRule.configAliases`), so an alias entry would be a one-line addition rather than a new rule.
- **Recommendation:** do not implement a new rule. Update `plans/GAP_ANALYSIS.md` to reclassify this solid_lints item as HAVE (via `prefer_immediate_return`), optionally adding a config alias `avoid_unnecessary_return_variable` for discoverability by users coming from solid_lints.

---

## Decision

---

## Implementation Notes

If the alias route is chosen instead of a new rule: add `'avoid_unnecessary_return_variable'` to a `configAliases` getter on `PreferImmediateReturnRule` in `lib/src/rules/flow/return_rules.dart`, following the pattern already used by `BannedUsageRule.configAliases` in `lib/src/rules/code_quality/code_quality_avoid_rules.dart:4467`.

---

## Commits
