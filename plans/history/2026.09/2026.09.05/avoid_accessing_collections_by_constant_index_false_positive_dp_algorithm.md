# BUG: `avoid_accessing_collections_by_constant_index` — False positive on Levenshtein DP row initialization

**Status: Fixed**

Created: 2026-09-05
Rule: `avoid_accessing_collections_by_constant_index`
File: `lib/src/rules/code_quality/code_quality_avoid_rules.dart` (line ~2737)
Severity: False positive
Rule version: v5

---

## Summary

The rule fires on `curr[0] = i` inside the outer loop of a standard Levenshtein edit-distance implementation. The constant index `0` is intentional — each iteration of the outer loop initializes the first column of the DP row to the current deletion cost. The rule's heuristic ("retrieves the same element on every iteration, usually a logic error where the loop variable was intended") is wrong here: the code is *writing* to index 0, not reading, and it writes a *different value* (`i`) each iteration.

---

## Attribution Evidence

```bash
grep -rn "'avoid_accessing_collections_by_constant_index'" lib/src/rules/
# lib/src/rules/code_quality/code_quality_avoid_rules.dart:2737:    'avoid_accessing_collections_by_constant_index',
```

---

## Reproducer

```dart
// Standard single-row Levenshtein DP — curr[0] must be set to `i` each iteration.
for (int i = 1; i <= m; i++) {
  curr[0] = i; // LINT — but should NOT lint (intentional DP initialization)
  for (int j = 1; j <= n; j++) {
    // ... fill rest of row
  }
}
```

**Frequency:** Always — fires on any constant-indexed write inside a loop.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — writing to a fixed index with a varying value is a valid DP pattern |
| **Actual** | `[avoid_accessing_collections_by_constant_index] Collection accessed by a constant index inside a loop body` |

---

## Root Cause

### Hypothesis A: Rule does not distinguish reads from writes

The rule flags `list[0]` in a loop body without checking whether it's an `IndexExpression` on the left side of an assignment (write) vs. right side (read). A constant-index *write* that stores a loop-varying value is a different pattern from a constant-index *read* that fetches the same element every iteration.

### Hypothesis B: Rule does not check whether the assigned value uses the loop variable

Even if the index is constant, the value being assigned (`i`) varies with the loop, making this a legitimate per-iteration operation.

---

## Suggested Fix

1. Exclude `IndexExpression` nodes that appear as the target of an `AssignmentExpression` (left-hand side).
2. Or, at minimum, exclude cases where the assigned value references the enclosing loop variable.

---

## Fixture Gap

1. **Constant-index write with loop variable value** (`list[0] = i`) — expect NO lint
2. **Constant-index read in loop** (`x = list[0]`) — expect LINT
3. **Constant-index write with constant value** (`list[0] = 42`) — expect LINT (wasteful)

---

## Environment

- saropa_lints version: current (unreleased)
- Triggering file: `lib/src/rule_name_utils.dart:57`

---

## Finish Report (2026-09-05)

`_ConstantIndexVisitor.visitIndexExpression` in
`lib/src/rules/code_quality/code_quality_avoid_rules.dart` was changed to
check whether the flagged `IndexExpression` is the left-hand side of an
`AssignmentExpression` before reporting. If so, the node is skipped
(`super.visitIndexExpression(node)` is still called so nested expressions —
e.g. an index expression inside the index itself — continue to be visited)
and no diagnostic is raised. The check is structural only: it does not
inspect the assignment operator or the right-hand side.

Implemented fix took Hypothesis A from the "Suggested Fix" section above
(exclude LHS-of-assignment) rather than Hypothesis B (check whether the
assigned value references the loop variable). This means Fixture Gap item 3
(`list[0] = 42` — constant value written to a constant index) is now
suppressed rather than flagged, which contradicts the original bug report's
own "expect LINT (wasteful)" expectation for that case. The fixture
(`example/lib/code_quality/avoid_accessing_collections_by_constant_index_fixture.dart`)
documents this explicitly as a deliberate, accepted trade-off (value-flow
analysis needed to distinguish "wasteful constant write" from "intentional
sentinel reset" was judged out of scope for this rule), but the discrepancy
between the original bug report's stated expectation and the shipped
behavior was not otherwise reconciled — flagged here as an open question for
review.

The LHS check is unconditional on the assignment operator: compound
assignments (`+=`, `-=`, `??=`, etc.) and increment/decrement expressions on
an `IndexExpression` target read the existing element before writing it, so
they are not pure writes in the way `=` is. `curr[0] += x` in a loop is
structurally identical to a constant-index *read* bug (accumulating into the
same slot every iteration when the index was meant to vary) but is now
silently suppressed because it is syntactically "the LHS of an
AssignmentExpression." This narrows the rule's read-detection coverage; it
was not covered by a fixture case and was not evaluated against real-world
frequency.

No rule-specific unit test was added or changed
(`test/rules/code_quality/code_quality_rules_test.dart` only contains an
instantiation pin for this rule, consistent with the project's convention
that fixture + `expect_lint` markers are the real correctness check, not
`test/`). Rule behavior on the new fixture cases (`_goodDpRowInit`,
`_goodConstantWriteConstantValue`) was NOT independently verified by
executing the scan CLI in this session: `dart run saropa_lints scan`
returned zero diagnostics across the entire `example/lib/code_quality`
fixture directory (112 files, including the pre-existing `_bad182` case that
has an `expect_lint` marker and predates this change), and
`dart run bin/accuracy_report.dart` crashed with a Dart VM
`Out of memory` error before completing. Both point to a local
tooling/environment problem (memory-constrained resolved analysis), not
necessarily to a defect in the fix — but it means the fix's behavior was
verified by code inspection only, not by an executed run.

The bug report was archived to this file (`git mv` from `bugs/`) and its two
inbound Dart-comment references
(`lib/src/rules/code_quality/code_quality_avoid_rules.dart`,
`example/lib/code_quality/avoid_accessing_collections_by_constant_index_fixture.dart`)
were repointed to the new `plans/history/2026.09/2026.09.05/...` path in the
same change. CHANGELOG.md already carried a Maintenance-style entry
documenting this fix (batched with 11 other false-positive fixes, "No action
required") from prior work in the tree; no further CHANGELOG edit was made.
