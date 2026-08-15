# BUG: `move_variable_closer_to_its_usage` — No Concept of a Deliberate Batch-Load / Batch-Assign Grouping

**Status: Fixed**

Created: 2026-08-15
Rule: `move_variable_closer_to_its_usage`
File: `lib/src/rules/code_quality/code_quality_variables_rules.dart` (line ~2286)
Severity: False positive
Rule version: v8 | Since: v0.1.4 | Updated: v13.10.4

---

## Summary

The rule flags any variable whose declaration and first use are separated by
`>= 3` intervening sibling statements in the same block, with no exception for
a deliberate "load everything, then assign everything" grouping — e.g. five
sequential `await`-loads followed immediately by five field assignments that
consume those loads in the same order. Each earlier-declared variable in the
load group accumulates more intervening statements than the threshold purely
because of its position in the group, even though the block reads as one
legible two-phase unit. Confirmed 6 false positives on this exact shape in
`lib/main.dart`.

---

## Attribution Evidence

```bash
grep -rn "'move_variable_closer_to_its_usage'" lib/src/rules/
# lib/src/rules/code_quality/code_quality_variables_rules.dart:2306:    'move_variable_closer_to_its_usage',
```

**Emitter registration:** `lib/src/rules/code_quality/code_quality_variables_rules.dart:2306`
**Rule class:** `MoveVariableCloserToUsageRule` — registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

Anonymized/reconstructed from `lib/main.dart`'s startup sequence — the
"load N independent results, then assign N fields from them in the same
order" shape that a prior triage session found flagged 6 times in that file.
Structure preserved: N sequential loads, then a block that consumes all N in
declaration order.

```dart
Future<StartupResult> loadStartup() async {
  final bool driftOk = await initDrift();          // LINT — declared far from use
  final bool prefsOk = await initPrefs();           // LINT — declared far from use
  final bool permsOk = await initPermissions();     // LINT — declared far from use
  final bool envOk = await initEnvOverrides();      // LINT — declared far from use
  final bool cacheOk = await warmCache();           // LINT — declared far from use

  // Deliberate second phase: assign everything in the same order the loads
  // happened, so a reader can hold "5 loads -> 5 assigns, same order" as one
  // unit rather than needing each declaration inlined at its use site.
  final StartupResult result = StartupResult();
  result.driftOk = driftOk;
  result.prefsOk = prefsOk;
  result.permsOk = permsOk;
  result.envOk = envOk;
  result.cacheOk = cacheOk;
  return result;
}
```

**Frequency:** Always, whenever a batch of N declarations precedes a block of
N consuming statements in the same order, and N is large enough that the
first declaration's distance to its use exceeds `_minInterveningStatements`.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the declarations and their uses are each one line apart from the equivalent step in the other phase; the "distance" is an artifact of the batch shape, not disorganized code |
| **Actual** | `[move_variable_closer_to_its_usage] Variable declared far from its first use...` reported on `driftOk`, `prefsOk`, `permsOk`, and `envOk` (every declaration except the last, which has fewer than 3 intervening statements before its use) |

---

## AST Context

```
Block (function body)                                ← context.addBlock
  ├─ VariableDeclarationStatement (driftOk)           ← declIndex = 0
  ├─ VariableDeclarationStatement (prefsOk)           ← declIndex = 1
  ├─ VariableDeclarationStatement (permsOk)           ← declIndex = 2
  ├─ VariableDeclarationStatement (envOk)             ← declIndex = 3
  ├─ VariableDeclarationStatement (cacheOk)           ← declIndex = 4
  ├─ VariableDeclarationStatement (result)            ← declIndex = 5
  ├─ ExpressionStatement (result.driftOk = driftOk)   ← useIndex = 6; driftOk: 6-0-1=5 >= 3 -> LINT
  ├─ ExpressionStatement (result.prefsOk = prefsOk)   ← useIndex = 7; prefsOk: 7-1-1=5 >= 3 -> LINT
  ├─ ExpressionStatement (result.permsOk = permsOk)   ← useIndex = 8; permsOk: 8-2-1=5 >= 3 -> LINT
  ├─ ExpressionStatement (result.envOk = envOk)       ← useIndex = 9; envOk: 9-3-1=5 >= 3 -> LINT
  ├─ ExpressionStatement (result.cacheOk = cacheOk)   ← useIndex = 10; cacheOk: 10-4-1=5 >= 3 -> LINT
  └─ ReturnStatement (return result)
```

---

## Root Cause

`MoveVariableCloserToUsageRule._canMoveCloser`
(`lib/src/rules/code_quality/code_quality_variables_rules.dart:2370-2389`)
computes exactly two things:

```dart
final int declIndex = block.statements.indexOf(declStatement);
final int useIndex = block.statements.indexOf(useStatement);
if (declIndex < 0 || useIndex <= declIndex) return false;

return useIndex - declIndex - 1 >= _minInterveningStatements;
```

with `_minInterveningStatements = 3` (line 2319). This is a pure
"how many sibling statements sit between declaration and first use" count. It
has no model of *why* those statements sit in between — specifically, it does
not check whether the intervening statements are themselves *other
declarations from the same batch*, nor whether the use site is part of a
block that consumes the whole batch in matching order (a legible,
deliberately two-phase structure the file's own comments call out explicitly,
per the class doc's note on `plans/history/2026.05/.../loop_accumulator.md`
handling a different false-positive class the same way — via a *structural*
carve-out, not a distance threshold). `_FirstUsageVisitor`
(lines 2392-2410) only records the first `SimpleIdentifier` reference by
name; it does not group declarations that share a "load phase" or correlate
them with a matching "assign phase."

The existing guard in `_canMoveCloser` (use-statement must be a direct child
of the same block, not nested in a loop/branch/closure) protects against a
different false-positive class (accumulator-in-loop) but does nothing for
this one, because the batch-load pattern's use sites ARE direct children of
the same block — they just happen to be several statements away by
construction.

---

## Suggested Fix

Before flagging, check whether the intervening statements between `decl` and
`useStatement` are themselves `VariableDeclarationStatement`s that are *also*
flagged as moving toward a use in the *same* following block, in the *same*
relative order as their declarations (i.e., detect the "N declarations, then N
consuming statements referencing them in matching order" shape) and suppress
the diagnostic for the whole group when found. A simpler, more conservative
alternative: only count *non-declaration* statements as "intervening" —
i.e., don't penalize a variable for sitting near siblings that are themselves
declarations awaiting their own later use.

---

## Fixture Gap

The fixture at
`example*/lib/code_quality/move_variable_closer_to_its_usage_fixture.dart`
should include:

1. Five sequential `await`-loaded locals followed immediately by five
   assignment statements consuming them in the same declared order — expect
   NO lint (current: LINT on the first four)
2. A single declaration genuinely far from its one use, with unrelated logic
   in between (the rule's actual target case) — expect LINT (must keep
   working)
3. Two declarations, unrelated intervening statements, each used far apart in
   *different* order than declared — expect LINT (batch-grouping carve-out
   must not blanket-suppress real cases)

---

## Changes Made

`_canMoveCloser` in `lib/src/rules/code_quality/code_quality_variables_rules.dart`
no longer counts every intervening sibling statement toward the distance
threshold. `runWithReporter` now precomputes, per block: which statement
indices are declarations (`isDeclStatement`), which direct-child statements
hold the first use of a block-declared variable and which variable names
(`useStatementVars`), and the set of variable names with any recorded first
use at all (`consumedVars`). `_canMoveCloser` computes the maximal
*contiguous* run of declaration statements containing `decl` (its "load
group") and only exempts an intervening statement from the distance count
when it is genuinely part of that same batch: another declaration in the
same contiguous run whose variable is itself in `consumedVars` (i.e. used
somewhere, not dead clutter), or the first-use statement of another
variable declared within that same run.

An initial version of this fix (committed as f24de443) exempted *any*
declaration statement or *any* block-declared variable's first-use statement
regardless of relation to the specific decl/use pair being measured — a
subsequent review caught that this caused a false NEGATIVE: unused "padding"
declarations sitting next to a genuinely lonely declaration would silently
suppress the lint (since they were declarations, full stop). The contiguity
and "must be genuinely consumed" requirements close that hole while keeping
the original batch-load fix intact.

Rule version bumped to v9, class doc and message tag updated to match. Added a
`_loadStartup`/`_StartupResult` "left alone" doc example.

---

## Tests Added

`example/lib/code_quality/move_variable_closer_to_its_usage_fixture.dart`:

- `_loadStartup` — five sequential loads followed by five assignments
  consuming them in the same order; expect NO lint on any of the five.
- `_outOfOrderUseNotABatch` — two declarations separated by genuinely
  unrelated statements, used out of declared order in one shared statement;
  expect LINT on both (batch carve-out must not blanket-suppress real cases).
- `_unusedPaddingDeclarationsNotABatch` — one real declaration/use pair with
  three unused padding declarations sitting in between; expect LINT on the
  real one (batch carve-out must not exempt dead-clutter declarations that
  are never consumed anywhere).

Verified via `dart run saropa_lints scan example/lib/code_quality --tier
comprehensive --resolve --format json`: `move_variable_closer_to_its_usage`
fires only at lines 117, 212, 214, 230 (the four `expect_lint` markers) and
nowhere inside `_loadStartup`. `dart test
test/rules/code_quality/code_quality_rules_test.dart` — 215/215 passed
(instantiation-pin test for this rule unaffected).

---

## Commits

- `f24de443` — initial fix (batch-load false positive resolved; introduced a
  false negative caught by review).
- Follow-up commit (this session) — tightened to contiguous-run + genuine-use
  requirement, closing the false negative.

---

## Environment

- saropa_lints version: (repo HEAD at filing time)
- Dart SDK version: n/a
- custom_lint version: n/a
- Triggering project/file: downstream Flutter/Dart app (contacts), 6 occurrences
  in `lib/main.dart` on this shape

---

## Finish Report (2026-08-15)

`move_variable_closer_to_its_usage` flagged a deliberate "load N values, then
consume all N in the same order" grouping (e.g. five sequential `await`-loads
followed by five field assignments) because its distance calculation counted
every intervening sibling statement without regard for whether that sibling
was itself part of the same declare/consume story.

`_canMoveCloser` in `lib/src/rules/code_quality/code_quality_variables_rules.dart`
now excludes an intervening statement from the distance count only when it
is genuinely part of the same batch as the declaration being measured: a
sibling declaration in the same *contiguous* run of declarations whose own
variable is itself used somewhere in the block (not unused padding sitting
nearby), or the first-use statement of another variable from that same run.
An initial version of the fix exempted any declaration or any block
variable's first-use statement regardless of relation to the specific pair
being measured; a deep-review pass caught that this introduced a false
negative (unused padding declarations silently suppressing a genuinely far
declaration), which the contiguous-run-plus-genuine-use requirement closes.

Rule version bumped to v9 (message tag and class doc updated to match). Four
fixture cases now exercise the rule: the original single-declaration true
positive, the new batch-load true negative, an out-of-order-use true
positive (guards against blanket suppression), and an unused-padding true
positive (guards against the false negative found in review). Verified via
`dart run saropa_lints scan example/lib/code_quality --tier comprehensive
--resolve --format json` (all four `expect_lint` markers fire, nothing else
in the batch function) and `dart test
test/rules/code_quality/code_quality_rules_test.dart` (215/215 passed).
