# BUG: `move_variable_outside_iteration` — Fires on a variable whose initializer reads a local reassigned later in the loop body

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-19
Rule: `move_variable_outside_iteration`
File: `lib/src/rules/code_quality/code_quality_variables_rules.dart` (line ~2324)
Severity: False positive — **High** (the suggested hoist changes behavior and breaks correctness; teams must add `// ignore:` on common ancestor-walk loops)
Rule version: v4 | Since: v0.1.4 | Updated: v4.13.0

---

## Summary

The rule flags a variable declared and assigned inside a loop body as "produces the same value on every iteration" and tells the developer to hoist it above the loop. But the flagged variable's initializer references a local (`dir`) that is **reassigned at the bottom of the loop**, so the value differs each iteration. Hoisting it out would compute it once against the initial value and break the loop's logic. Expected: no diagnostic.

---

## Attribution Evidence

Grep proof that this rule lives in `saropa_lints`. If the positive grep is empty, the bug does not belong in this repo — do not file here. See "Confirm Attribution Before Filing" in the guide.

```bash
# Positive — rule IS defined here
grep -rn "'move_variable_outside_iteration'" lib/src/rules/
# lib/src/rules/code_quality/code_quality_variables_rules.dart:2324:    'move_variable_outside_iteration',

# Negative — rule is NOT in sibling repos (source label is ambiguous across projects)
grep -rn "move_variable_outside_iteration" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# 0 matches (the string appears only in that project's analysis_options.yaml, not in its source)
```

**Emitter registration:** `lib/src/rules/code_quality/code_quality_variables_rules.dart:2324`
**Rule class:** `MoveVariableOutsideIterationRule` — registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` (saropa_lints custom_lint plugin)

---

## Reproducer

Minimal Dart code that triggers the bug. Reduced from `saropa_drift_advisor/lib/src/server/generation_handler.dart` (ancestor-walk for the package config).

```dart
Directory dir = Directory.current.absolute;
while (true) {
  // LINT move_variable_outside_iteration — but the value depends on `dir`,
  // which is reassigned at the bottom of this loop, so it is NOT invariant.
  final configFile = File('${dir.path}/.dart_tool/package_config.json');

  // ... use configFile (read/parse if it exists) ...

  final parent = dir.parent;
  if (parent.path == dir.path) break; // reached filesystem root
  dir = parent; // <-- dir mutates every iteration → configFile differs each pass
}
```

Hoisting `configFile` above the loop, as the correction message instructs, computes
`File('${dir.path}/...')` once against `Directory.current` and never re-evaluates it
as `dir` walks up the tree — the ancestor walk silently stops working.

The same pattern recurs in two other ancestor-walk loops in that file —
`_discoverPackageRootPathFromAncestorWalk` and `_discoverPackageRootFromExecutablePath` —
each building `File('${dir.path}/lib/saropa_drift_advisor.dart')` from the same
reassigned `dir`.

**Frequency:** Always, when the in-loop variable's initializer references a local that is reassigned elsewhere in the loop body (the updater statement, an `AssignmentExpression`, or a `++`/`--`).

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the variable's value depends on `dir`, which mutates inside the loop, so it is not loop-invariant |
| **Actual** | `[move_variable_outside_iteration] Variable declared and assigned inside a loop body produces the same value on every iteration ...` reported at the `configFile` declaration |

---

## AST Context

The rule walks `WhileStatement.body` (a `Block`), iterates its top-level statements,
and for each `VariableDeclarationStatement` evaluates the initializer with
`_isLoopInvariant`. It never inspects the rest of the block for mutations of the
identifiers that the initializer reads.

```
WhileStatement
  └─ Block (loop body)
      ├─ VariableDeclarationStatement
      │   └─ VariableDeclaration (configFile)         ← node reported here
      │       └─ InstanceCreationExpression (File(...))
      │           └─ StringInterpolation '${dir.path}/.dart_tool/...'
      │               └─ InterpolationExpression
      │                   └─ PropertyAccess (dir.path)
      │                       └─ SimpleIdentifier (dir)   ← initializer READS `dir`
      ├─ ... (use of configFile) ...
      ├─ VariableDeclarationStatement (parent = dir.parent)
      ├─ IfStatement (break)
      └─ ExpressionStatement
          └─ AssignmentExpression (dir = parent)        ← `dir` WRITTEN here, same block
              └─ SimpleIdentifier (dir)  [leftHandSide]
```

The rule reports on `configFile` but never visits the `AssignmentExpression (dir = parent)`
sibling statement that makes the initializer non-invariant.

---

## Root Cause

`_isLoopInvariant` (line ~2369) decides "same value every iteration" purely from the
**syntactic shape of the initializer**, with no data-flow check against the rest of
the loop body. It returns `true` for:

- An `InstanceCreationExpression` whose every argument satisfies `_isConstant`
  (lines ~2371–2377), and
- A `MethodInvocation` on a capitalized target (treated as a static call) whose every
  argument satisfies `_isConstant` (lines ~2379–2392).

`_isConstant` (line ~2397) accepts only `Literal` and `NamedExpression` wrapping a
literal. So far this would correctly reject `File('${dir.path}/...')`, because a
`StringInterpolation` argument is not a `Literal`.

### Hypothesis A: `StringInterpolation` is treated as constant — CONFIRMED as the trigger

`File('${dir.path}/.dart_tool/package_config.json')` is an `InstanceCreationExpression`
(`File(...)`). Its single argument is a `StringInterpolation`. `_isConstant` returns
`false` for a `StringInterpolation` (it is not a `Literal` and not a `NamedExpression`),
which would make `_isLoopInvariant` return `false` and **not** flag the line.

Therefore the reproducer as written above should be re-checked against the actual
emitting form: the diagnostic fires, so the initializer that reaches the rule is being
classified as invariant. Two ways this happens, both rooted in the same missing
data-flow analysis:

1. The real initializer in the codebase is a `File(...)` / `Directory(...)` /
   capitalized static call whose arguments the rule's shape check happens to accept
   as constant (for example a non-interpolated argument, or an argument the rule's
   narrow `_isConstant` mis-accepts), while the value still varies because a *different*
   referenced local mutates each pass.

2. Independent of which argument form is used: the rule has **no concept of identifier
   liveness**. Even when `_isConstant` is widened (or when a future change accepts more
   initializer shapes such as interpolations), the rule will still flag any
   "constant-shaped" initializer that reads a loop-mutated local, because it never
   collects the locals the initializer reads and never checks whether any of them is
   assigned in the loop body.

### Hypothesis B (the actual structural defect): no liveness check of referenced locals

The core bug is structural and independent of the `_isConstant` edge case: a "loop
invariant" expression is one whose value cannot change across iterations. The rule
approximates this with "the initializer is built from constructor/static-call shapes
over literals," but that approximation is unsound the moment the initializer reads ANY
local, because a local read by the initializer can be reassigned later in the same loop
body (the updater statement, an `AssignmentExpression`, a `++`/`--`, or a pattern
assignment). The rule never gathers the set of identifiers the initializer reads, and
never scans the loop body for writes to them. That missing check is what produces the
false positive on every ancestor-walk loop.

---

## Suggested Fix

In `_isLoopInvariant` (line ~2369) — or in `checkLoopBody` (line ~2336) before calling
`reporter.atToken` at line ~2349 — add a data-flow guard:

1. **Collect the locals the initializer reads.** Visit `initializer` with a
   `RecursiveAstVisitor` that records every `SimpleIdentifier` resolving to a
   `LocalVariableElement` / parameter (a `_FirstUsageVisitor`-style collector already
   exists in this file at line ~2266 and can serve as the pattern). Call this set
   `readLocals`.

2. **Collect the locals written anywhere in the loop body.** Visit the loop body
   `Block` (and, for `ForStatement`, the `forLoopParts` updaters and any
   pattern/loop variable) for:
   - `AssignmentExpression.leftHandSide` that is a `SimpleIdentifier`,
   - `PostfixExpression` / `PrefixExpression` operands (`i++`, `--i`),
   - the `ForStatement` updater expressions and the for-each loop variable / pattern.

   Call this set `writtenLocals`.

3. **Suppress when they intersect.** If `readLocals ∩ writtenLocals` is non-empty, the
   initializer is not loop-invariant — `return false` (do not flag). Only when the
   initializer reads no loop-mutated local may the rule report.

This makes the ancestor-walk loops pass cleanly (`configFile` reads `dir`; `dir` is in
`writtenLocals` via `dir = parent`), while still flagging the genuine
`final regex = RegExp(r'\d+');` case (reads no loop-mutated local).

Keep the change within the rule's function-length budget by extracting the two
collectors into small `RecursiveAstVisitor` subclasses alongside `_FirstUsageVisitor`
(line ~2266) rather than inlining the traversal in `_isLoopInvariant`.

Add a comment at the new guard stating the failure mode it prevents: a variable whose
initializer reads a local that is reassigned later in the loop body is recomputed each
pass on purpose, and hoisting it would freeze it at the first iteration's value and
break ancestor-walk / accumulator loops.

---

## Fixture Gap

The fixture at `example*/lib/code_quality/move_variable_outside_iteration_fixture.dart`
should include:

1. **Ancestor walk with reassigned loop local** — `while (true) { final f = File('${dir.path}/x'); ...; dir = dir.parent; }` — expect **NO lint** (value depends on reassigned `dir`).
2. **`for` loop reading the loop counter that the updater mutates** — `for (var i = 0; i < n; i++) { final k = 'key$i'; ... }` — expect **NO lint** (reads `i`, mutated by the updater).
3. **Prefix/postfix mutation of a read local** — initializer reads `j`; body contains `j++` — expect **NO lint**.
4. **Genuine invariant** — `final regex = RegExp(r'\d+');` inside a loop, reads no loop-mutated local — expect **LINT** (regression guard that the fix does not over-suppress).
5. **Constructor over literals only** — `final p = Point(0, 0);` inside a loop — expect **LINT** (still invariant).

---

## Changes Made

**Root cause confirmed:** the doc's Hypothesis A had the AST hierarchy inverted —
`StringInterpolation` *extends* `Literal` in the analyzer, so `_isConstant('${dir.path}/...')`
returns `true` and `File('${dir.path}/...')` (an `InstanceCreationExpression` once
resolved) is classified as invariant. The structural defect (Hypothesis B — no
liveness check) is the real fix and resolves the StringInterpolation trigger too.

`lib/src/rules/code_quality/code_quality_variables_rules.dart`:

1. `MoveVariableOutsideIterationRule.runWithReporter` now computes the set of locals
   written anywhere in each loop (`_collectLoopWrittenLocals`) once per loop, and
   `checkLoopBody` skips any otherwise-invariant declaration whose initializer reads
   one of them (`_readsLoopMutatedLocal`). Reports only when both conditions hold.
2. Added two `RecursiveAstVisitor` collectors:
   - `_LoopWrittenLocalsCollector` — assignment targets, `++`/`--` operands, the
     for-each loop variable (`visitDeclaredIdentifier` /
     `visitForEachPartsWithIdentifier`). Visiting the whole loop node also captures
     the `for` updater; over-collecting into nested loops is safe (only suppresses).
   - `_ReadLocalsCollector` — base-identifier reads in the initializer, excluding
     property names, method names, named-argument labels, and declarations.

The guard is purely syntactic, so it works in both the resolved (custom_lint) and
unresolved (scan CLI) environments.

---

## Tests Added

- `test/rules/code_quality/move_variable_outside_iteration_fp_test.dart` — six
  oracle-backed cases via the resolved-AST harness (`test/support/resolved_rule_harness.dart`),
  required because the scan CLI runs on **unresolved** ASTs where `File(...)` /
  `RegExp(...)` parse as `MethodInvocation` (no target) and the rule never fires.
  NO-LINT: ancestor walk (`dir` reassigned), `for` counter read, `j++`-mutated read.
  LINT (regression guards): `RegExp(r'\d+')`, zero-arg `StringBuffer()`, and an
  interpolation that reads only a loop-invariant outer local. Confirmed the three
  NO-LINT cases fail against the pre-fix rule.
- `example/lib/code_quality/move_variable_outside_iteration_fixture.dart` — added the
  same five scenarios (`// expect_lint` on the two genuine cases) alongside the
  existing fixture. Note: these do not exercise detection under the scan CLI for the
  reason above; the resolved harness is the authoritative check.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Finish Report (2026-06-19)

### Defect

`move_variable_outside_iteration` reported a loop-body variable as loop-invariant
and advised hoisting it, even when the declaration's initializer read a local that
the loop reassigns. On the canonical ancestor-walk loop
(`final f = File('${dir.path}/x'); ...; dir = dir.parent;`) the suggested hoist
would compute the path once against the starting directory and never re-evaluate it,
silently breaking the walk. The rule decided invariance from the initializer's
syntactic shape alone, with no data-flow check against the rest of the loop body.

### Root cause

Two compounding facts:

1. `_isConstant` accepts any `Literal`, and in the analyzer AST `StringInterpolation`
   extends `Literal`. So `File('${dir.path}/...')` (an `InstanceCreationExpression`
   after resolution) with a single interpolated-string argument was classified as
   constant, hence invariant. The bug report's Hypothesis A had this hierarchy
   inverted; the correction here records the actual relationship.
2. The structural defect (the report's Hypothesis B): the rule never gathered the
   identifiers an initializer reads, nor scanned the loop for writes to them, so any
   constant-shaped initializer reading a loop-mutated local was flagged.

### Fix

In `lib/src/rules/code_quality/code_quality_variables_rules.dart`, a syntactic
data-flow guard was added to `MoveVariableOutsideIterationRule`:

- `_collectLoopWrittenLocals` runs once per `for` / `while` / `do` loop and records
  every local written in it — assignment targets, `++`/`--` operands, the `for`
  updater, and the for-each loop variable — via a new `_LoopWrittenLocalsCollector`.
- `checkLoopBody` reports an otherwise-invariant declaration only when its
  initializer reads none of those locals, tested by `_readsLoopMutatedLocal` over a
  new `_ReadLocalsCollector` (base identifier reads only; property names, method
  names, named-argument labels, and declarations are excluded).

Over-collecting writes into nested loops can only suppress a diagnostic, never add
one, so the guard is conservative. Being purely syntactic, it behaves identically in
the resolved (custom_lint) and unresolved (scan CLI) environments.

### Verification

`test/rules/code_quality/move_variable_outside_iteration_fp_test.dart` exercises the
rule through the resolved-AST harness (`test/support/resolved_rule_harness.dart`),
necessary because the scan CLI runs on unresolved ASTs where `File(...)` /
`RegExp(...)` parse as a target-less `MethodInvocation` and the rule never fires.
Three NO-LINT cases (ancestor walk, `for` counter, `j++`) and three LINT regression
guards (`RegExp(r'\d+')`, zero-arg `StringBuffer()`, interpolation over a
loop-invariant outer local) all pass; the three NO-LINT cases were confirmed to fail
against the pre-fix rule. The `example/` fixture gained the same five scenarios. The
registration/metadata pin in `code_quality_rules_test.dart` is unaffected (rule name,
class, and message are unchanged).

---

## Environment

- saropa_lints version: 14.0.3
- Dart SDK version: 3.12.1
- custom_lint version: via custom_lint CLI
- Triggering project/file: `saropa_drift_advisor` — `lib/src/server/generation_handler.dart` (ancestor-walk loops: package-config discovery, `_discoverPackageRootPathFromAncestorWalk`, `_discoverPackageRootFromExecutablePath`)
