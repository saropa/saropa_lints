# BUG: `avoid_high_cyclomatic_complexity` — Flat Switch-Statement Lookup Tables Count as High Complexity

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-08-16
Rule: `avoid_high_cyclomatic_complexity`
File: `lib/src/rules/code_quality/complexity_rules.dart` (line ~1288, class at line ~1225)
Severity: False positive
Rule version: v1 | Since: v5.1.0

---

## Summary

`_ComplexityCounter` (in the same file) adds `+1` complexity for every
`case` (`visitSwitchPatternCase`), identical to how it treats an `if`, `for`,
or `&&`/`||` branch. A single-level `switch` whose every case is a one-line
`return` with no nesting and no compound conditions — a pure enum → value
lookup table — accumulates complexity linearly with the number of enum
variants, not with any actual logical branching. A 40-case lookup function
crosses the `_threshold = 15` purely from case count, even though it has
exactly the same cognitive load as a `Map<Enum, String>` literal (which the
rule would not flag at all). The rule already carves out an analogous
"mechanical, not logical" pattern for `copyWith` (doc comment,
`complexity_rules.dart:1224-1226`; code exclusion at lines 1306 and 1315) —
this is the same shape of false positive in a different mechanical pattern.

---

## Attribution Evidence

```bash
$ grep -rn "'avoid_high_cyclomatic_complexity'" lib/src/rules/
lib/src/rules/code_quality/complexity_rules.dart:1288:    'avoid_high_cyclomatic_complexity',
```

**Emitter registration:** `lib/src/rules/code_quality/complexity_rules.dart:1288`
**Rule class:** `AvoidHighCyclomaticComplexityRule` (`complexity_rules.dart:1225`)
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

Minimal reduction of the real hit at
`d:\src\contacts\lib\components\contact\action_icons\contact_action_icon_list.dart:367`
(`_actionLabelForIcon`, 40 cases, one-line `return` each, no nesting):

```dart
String? actionLabelForIcon(SomeEnum value) { // LINT — but should NOT lint (false positive)
  switch (value) {
    case SomeEnum.a: return 'A';
    case SomeEnum.b: return 'B';
    case SomeEnum.c: return 'C';
    // ... 37 more one-line cases, each a flat literal return ...
    case SomeEnum.z: return 'Z';
  }
}
```

Every case body is a single `return <literal-or-getter>` expression — no
`if`, no `for`, no `&&`/`||`, no nested `switch`. There are zero independent
*logical* execution paths beyond "which enum value came in," which is
exactly the shape a `Map<SomeEnum, String>` literal would express with zero
complexity warning.

**Frequency:** Always — any flat dispatch/lookup `switch` whose case count
exceeds `_threshold` (15) fires, regardless of whether the case bodies
contain any actual branching.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — flat one-line-per-case lookup table has no real branching complexity, same as the existing `copyWith` exclusion |
| **Actual** | `[avoid_high_cyclomatic_complexity] Functions with cyclomatic complexity exceeding 15 have too many branching paths...` reported at the function name |

---

## AST Context

```
FunctionDeclaration (_actionLabelForIcon)
  └─ FunctionExpression
      └─ BlockFunctionBody
          └─ Block
              └─ SwitchStatement (value)
                  ├─ SwitchPatternCase (case SomeEnum.a) ← +1 complexity, x40
                  ├─ SwitchPatternCase (case SomeEnum.b) ← +1 complexity
                  └─ ... (38 more, each a single ReturnStatement, no nested control flow)
```

`_ComplexityCounter.visitSwitchPatternCase` (`complexity_rules.dart:~1350`)
increments unconditionally per case, with no check of what the case body
contains.

---

## Root Cause

`_ComplexityCounter` treats every `case` label as equivalent to an `if`
branch for complexity-counting purposes (`visitSwitchPatternCase`,
`complexity_rules.dart`). This is true when case bodies themselves branch
further, but for a flat dispatch table (each case body is a single
statement with no nested control flow), the case count measures the
*enum's cardinality*, not the function's *logical* complexity — identical to
counting each `if (param == null) param = default;` line in a large
constructor and calling it "high complexity" (which is precisely the
rationale already written into this file's own `copyWith` exclusion at
`complexity_rules.dart:1224-1226`: "their apparent complexity is mechanical
... not logical, and does not match the rule's intent").

### Hypothesis A: Weight switch cases by case-body complexity, not by count

Instead of `+1` per case unconditionally, only add complexity per case when
the case body itself contains more than a single `ReturnStatement`/
`ExpressionStatement` (i.e. the case body has internal branching). A flat
`case X: return Y;` contributes 0 or a fractional weight; a case with a
nested `if`/loop still contributes normally via the existing visitors.

### Hypothesis B: Exempt switch statements where every case is a single trivial statement

Detect the "pure dispatch table" shape structurally (every `SwitchMember`'s
statement list has length 1, and that one statement is a `ReturnStatement`
or a single assignment with no compound condition) and skip counting the
switch's cases entirely — treating the whole `SwitchStatement` as `+1`
(same as a single `if`), not `+1` per case.

---

## Suggested Fix

Prefer Hypothesis B — simpler to reason about and matches the intent of the
existing `copyWith` carve-out (detect the mechanical pattern structurally,
exempt it, keep counting normally for anything with real nested logic
inside a case body). Implement in `visitSwitchPatternCase` or by adding a
`visitSwitchStatement` override that pre-classifies the whole statement
before descending.

---

## Fixture Gap

The fixture at `example*/lib/code_quality/avoid_high_cyclomatic_complexity_fixture.dart`
should include:

1. **Flat switch, >15 cases, every case body a single `return <literal>`,
   no nesting** — expect NO lint (new case).
2. **Switch with >15 cases where at least one case body contains an `if` or
   nested `switch`** — expect LINT (existing true-positive case, should
   remain covered — complexity is genuinely higher than case-count alone).
3. **Switch with >15 cases where every case does a multi-step
   transformation (not a flat return)** — needs a decision: still borderline
   real complexity, worth a fixture comment either way.

---

## Changes Made

- `_ComplexityCounter` (in `complexity_rules.dart`) now overrides `visitSwitchStatement` to detect flat dispatch tables before descending. A flat dispatch table is a switch where every case body is exactly one trivial statement (return, break, continue, or expression statement with no ternaries, logical operators, or nested control flow).
- When a switch is classified as flat, it adds +1 for the whole switch and skips per-case counting in `visitSwitchPatternCase`.
- Added `_HasBranchingVisitor` — a small AST visitor that detects complexity-contributing nodes inside a statement, used by the trivial-statement check.
- Updated rule doc comment to document the flat-switch exclusion alongside the existing `copyWith` exclusion.

---

## Tests Added

- `example/lib/complexity/avoid_high_cyclomatic_complexity_fixture.dart`: added `_flatSwitchLookup` (18 flat return cases, GOOD — should NOT lint) and `_switchWithNestedBranching` (17 cases with ternary expressions in each body, BAD — should LINT).
- Existing `complexity_rules_test.dart` passes (instantiation + fixture existence checks).

---

## Commits

<!-- Add commit hashes as fixes land. -->

## Finish Report (2026-08-16)

### Defect
`avoid_high_cyclomatic_complexity` counted +1 per `SwitchPatternCase` unconditionally, causing flat enum→value dispatch tables (every case a single return with no nesting) to exceed the threshold of 15 purely from enum cardinality. A 40-case lookup function scored 41 complexity despite having zero logical branching beyond "which enum value."

### Fix
Added `visitSwitchStatement` to `_ComplexityCounter` that pre-classifies the switch as a flat dispatch table before descending. Classification requires: at least 2 members, every member is `SwitchPatternCase` or `SwitchDefault`, no guard clauses (`when`), exactly one statement per case, and that statement contains no complexity-contributing nodes (verified by `_HasBranchingVisitor`, which detects if/for/while/do/switch/try/ternary/&&/||/??). Flat switches use fractional weighting: `1.0 + (caseCount × 0.2)` instead of `+1` per case. Normal enum dispatches (≤70 cases) pass; extreme outliers still flag.

### Review findings addressed
- Guard-clause regression: `_isFlatDispatchTable` now rejects cases with `whenClause != null`, preventing guarded patterns from being misclassified as flat. Without this, `super.visitSwitchPatternCase` would be skipped and guard-clause branching would go uncounted.
- Empty switch guard: switches with fewer than 2 members are not classified as flat (vacuous-truth edge case).
- `try`/`catch` detection: `_HasBranchingVisitor` now detects `TryStatement` as branching.
- Removed dead `unused_local_variable` from fixture ignore directive.
- Removed invalid `visitNode` override that a hook injected (method does not exist on `RecursiveAstVisitor`).

### Known limitations (fail-safe, not regressions)
- Fallthrough-shared bodies (`case A: case B: return 'x';`) have `statements.length == 0` for the leading case, so the switch falls back to per-case counting. The flat-dispatch exemption does not cover this pattern — it still over-counts, but was already over-counting before this fix.
- A case body wrapped in a `Block` with multiple non-branching statements would pass `_HasBranchingVisitor` since it only checks for branching nodes, not statement count. Unlikely in practice since Dart switch cases don't wrap in blocks.

### Test coverage
Fixtures added to `example/lib/complexity/avoid_high_cyclomatic_complexity_fixture.dart`:
- `_flatSwitchLookup` (18 flat return cases, GOOD)
- `_flatSwitchWithDefault` (17 cases + default, GOOD)
- `_switchWithGuardClauses` (16 guarded cases + default, BAD — guards prevent flat classification)
- `_switchWithNestedBranching` (17 cases with ternaries, BAD)

Unit tests are instantiation pins per project convention; behavioral verification requires the scan CLI.

---

## Environment

- saropa_lints version: resolved via `d:\src\contacts\pubspec.yaml` (pub cache; local checkout at `d:\src\saropa_lints` had an unrelated pre-existing compile error at report time, not used for detection)
- Dart SDK version: (not captured this session)
- custom_lint version: (not captured this session)
- Triggering project/file: `d:\src\contacts\lib\components\contact\action_icons\contact_action_icon_list.dart:367` (`_actionLabelForIcon`, 40 cases)

---

## Sampling Note (for downstream `avoid_high_cyclomatic_complexity` triage)

4 samples taken across the 435-hit backlog this session:
- `activity_audit_panel.dart:118` (`build()`, 11+ `if` branches over real
  optional-field checks) — true positive.
- `activity_view_widget.dart:259` (`_fetchActivityViewData`, nested
  conditional async fetches with compound `&&` conditions) — true positive.
- `action_icon_email.dart:47` (prior session; icon-state `build()`
  branching) — true positive.
- `contact_action_icon_list.dart:367` (`_actionLabelForIcon`, flat 40-case
  switch) — **false positive, this bug**.

Recommendation: the FP rate for this rule is low (~1/4 sampled) and
concentrated specifically in flat-switch dispatch/lookup functions, not
spread generally. Do not mass-suppress the 435 hits; the majority sampled
are genuine. Worth a second sampling pass specifically targeting other
`switch`-heavy files (enum-to-string/icon/color mapping functions are a
common pattern in this codebase, e.g. other `*_action_icon_list.dart` /
enum-display-name helpers) once this bug's fix direction is picked, to
estimate how many of the 435 are this same switch-lookup shape.
