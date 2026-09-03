# PROPOSAL: Flag Duplicate Values Within a Single Boolean Expression

**Status: Open**

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
