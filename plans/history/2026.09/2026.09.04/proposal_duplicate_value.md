# PROPOSAL: Flag Duplicate Values Within a Single Boolean Expression

**Status: Implemented**

Created: 2026-09-02
Type: New rule
Related rules: `no_equal_conditions` (distinct — cross-branch, not within one expression)

---

## Summary

Add `duplicate_value` to flag the same sub-expression appearing more than once within a single boolean expression joined by `&&`/`||` (e.g. `a == 1 || a == 1`), which is always redundant and often signals a copy-paste typo where a different variable or value was intended.

**Closes gap:** `essential_lints` `duplicate_value`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "essential_lints" gaps section, which explicitly distinguishes this from saropa's existing `no_equal_conditions` (cross-branch `if`/`else if` duplication, not within-expression).

---

## Motivation

Saropa's `no_equal_conditions` catches duplicate whole conditions across `if`/`else if` branches, but does not catch the narrower and more common typo of repeating the same comparison twice inside one `&&`/`||` chain — e.g. `status == Status.open || status == Status.open` where the second clause was meant to check a different status. This is a distinct AST shape (single `BinaryExpression` tree) and a distinct bug class (copy-paste within one condition, not across branches).

---

## Detection / Behavior

### Should flag (bad code)

```dart
bool isEditable(Status status) {
  return status == Status.open || status == Status.open; // LINT — duplicate sub-expression; likely meant Status.draft or similar
}
```

### Should pass (good code)

```dart
bool isEditable(Status status) {
  return status == Status.open || status == Status.draft; // OK — distinct comparisons
}
```

---

## Proposed Tier

Tier: Recommended
Justification: near-certain bug signal (redundant comparison is either dead code or a typo) with negligible false-positive risk, matching saropa's placement for other high-confidence correctness rules.

---

## Edge Cases

1. **Duplicate comparison with a documented intentional no-op comment (`// duplicated intentionally for clarity`)** — should still flag; redundant regardless of intent, and the "clarity" argument doesn't hold since it's the identical clause.
2. **Duplicate call expressions with side effects (`getX() == 1 || getX() == 1`)** — should flag; even with side effects, the redundant boolean structure remains a bug smell, though the correction message should note the call is repeated.
3. **Structurally identical but differently-formatted sub-expressions (`a==1` vs `a == 1`)** — should flag; comparison is on the AST structure, not source text, so formatting differences don't evade detection.
4. **Three-or-more-way OR chain with only two of the clauses duplicated (`a==1 || b==2 || a==1`)** — should flag the duplicate pair, not require all clauses to match.

---

## Alternatives Considered

- **Extend `no_equal_conditions` to also cover within-expression duplicates** — rejected in favor of a separate rule; the AST traversal (single expression tree vs. sibling `if`/`else if` statements) and problem message differ enough that a combined rule would need internal branching, and the two are cleanly separable per the gap analysis's own distinction.

---

## Decision

---

## Implementation Notes

Compare sub-expressions structurally (AST equality, not source-text equality) within a single `BinaryExpression` chain of `&&`/`||` operators; reuse any existing structural-equality helper already used by `no_equal_conditions` if one exists.

---

## Commits

---

## Finish Report (2026-09-04)

### Issues

1. **False negative: same-operator chain broken by explicit parentheses is never flattened across the paren boundary** (`lib/src/rules/flow/duplicate_value_rules.dart`, `_collectOperands` line 120 and the root-skip check at lines 83-86). `_collectOperands` only descends when `expr is BinaryExpression` — a `ParenthesizedExpression` wrapping a nested `BinaryExpression` of the *same* operator fails that check and is treated as one opaque leaf instead of being flattened. Concretely, `a == 1 || (b == 2 || a == 1)` is NOT flagged: the outer collector sees leaves `["a == 1", "(b == 2 || a == 1)"]` (no match), and the inner `BinaryExpression(b == 2 || a == 1)` is visited separately by `context.addBinaryExpression` — its parent is the `ParenthesizedExpression`, not a `BinaryExpression`, so the root-skip check at line 84 does not fire and it is evaluated as an independent, isolated root with leaves `["b == 2", "a == 1"]` (also no match, since it has no visibility into the sibling operand outside the parens). Net effect: a duplicate comparison split across an explicit parenthesis group — a very common way to write grouped boolean conditions — silently evades detection. This is the mirror-image bug of the "mixed operators" case the rule correctly guards against (fixture `mixedOperators`), except here the operator *is* the same and it should have been flattened.
   - Fix direction: when descending in `_collectOperands`, unwrap parentheses first (analyzer's `Expression.unParenthesized` — not currently used anywhere in the codebase) before checking `expr is BinaryExpression`, and apply the same unwrap when computing `node.parent` for the root-skip check.

### Concerns

1. **No fixture/test exercises the parenthesized-same-operator case**, so the false negative above shipped undetected. All three BAD fixture entries (`isEditable`, `bothChecksMatch`, `sideEffectCall`) are flat, unparenthesized chains; the only parenthesized fixture (`mixedOperators`) deliberately uses *different* operators inside vs. outside, which the rule handles correctly — it does not probe the same-operator case at all.
2. **The unit test never proves the rule actually fires.** `test/rules/flow/duplicate_value_test.dart` only checks rule instantiation (code name, message contents, correction message non-null) and that the fixture file exists on disk — it never runs the rule against the fixture and asserts the `expect_lint` markers are satisfied. This matches the project-wide known limitation (unit tests are instantiation pins only; the scan CLI is the only way to prove firing — see `memory/reference_verify_rule_behavior_scan_cli.md`), so it is not unique to this PR, but combined with concern #1 it means the false negative was never going to surface from `dart test` alone.
3. **Tier placement diverges from the proposal without the "Decision" section being filled in.** The proposal (this file, "Proposed Tier" section) specifies Recommended; the rule is actually registered in `essentialRules` (`lib/src/tiers.dart` line 780, in the "Tier 1 quick wins — batch 4" block), one tier stricter/broader than proposed. The "Decision" section above (line 67-68) is blank, so there is no record of why the tier was escalated from Recommended to Essential. Functionally Essential is a defensible (arguably better) choice given the "negligible false-positive risk" justification already in the proposal, but the doc should reflect what actually shipped.
4. **Overlap with `avoid_conditions_with_boolean_literals` is untested.** A duplicate boolean-literal operand, e.g. `if (true || true)`, will be flagged by both `duplicate_value` and the existing literal-condition rule, producing two diagnostics on the same span. Not necessarily wrong, but worth a fixture/test to confirm the double-reporting is intentional rather than an oversight.
5. **Reporting cardinality for 3+ identical operands is implicit, not verified.** For `a==1 || a==1 || a==1`, the `seen`-set algorithm (lines 95-103) reports the 2nd and 3rd occurrences (two diagnostics), never the 1st. This is reasonable but isn't asserted anywhere, and a reviewer skimming the fixture (`bothChecksMatch` only has one duplicate pair among three operands) wouldn't learn the multi-duplicate behavior from it.
6. **Proposal's "Implementation Notes" section is factually inaccurate but harmless.** It instructs to "reuse any existing structural-equality helper already used by `no_equal_conditions` if one exists" and frames the choice as "AST equality, not source-text equality." No such helper exists — `no_equal_conditions` (`lib/src/rules/flow/control_flow_rules.dart` line 1664) also compares via `.toSource()` text, exactly like this rule. The shipped implementation is consistent with the sibling rule; the proposal document is just wrong about what `no_equal_conditions` does. Low priority since the code itself is fine and well-commented about the source-text choice.

### Opportunities

1. Introduce (or confirm/adopt if it exists elsewhere in the codebase) a shared `unParenthesized`-aware flattening helper for same-operator boolean chains, since both this rule and any future boolean-chain rule will need to handle explicit grouping parens correctly — fixing issue #1 here is also an opportunity to harden the pattern for reuse.
2. `duplicate_value_test.dart` could adopt the shared `discoverFixtures`/fixture-existence helper (`test/helpers/fixture_discovery.dart`) already used by `control_flow_rules_test.dart` instead of hand-rolling a single `File(...).existsSync()` check — minor consistency win, not a defect.

### Recommendations

1. **(High)** Fix the parenthesized same-operator flattening gap in `_collectOperands` and the root-skip check using `Expression.unParenthesized`, then add a fixture case (e.g. `a == 1 || (b == 2 || a == 1)`) with `expect_lint` and verify it fires via the scan CLI (`dart run saropa_lints scan <dir> --tier comprehensive --files <fixture> --format json`), per the project's standard verification path — unit tests alone won't catch this.
2. **(Medium)** Add a fixture/test for the boolean-literal overlap with `avoid_conditions_with_boolean_literals` to confirm double-reporting is expected, or suppress one of the two if it's noise.
3. **(Low)** Fill in the proposal's blank "Decision" section noting the actual shipped tier (Essential, not Recommended) and why.
4. **(Low)** Correct the "Implementation Notes" section's claim about `no_equal_conditions` using structural AST equality — it uses `.toSource()` text comparison, same as this rule.
