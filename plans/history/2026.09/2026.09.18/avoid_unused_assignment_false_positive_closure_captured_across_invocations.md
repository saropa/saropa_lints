# BUG: `avoid_unused_assignment` flags a closure-captured variable reset, comparing it against an unrelated assignment in a different closure by source order instead of execution order

**Status: Open**

Created: 2026-09-18

Rule: `avoid_unused_assignment`
File: `lib/src/rules/code_quality/code_quality_variables_rules.dart` (line ~1123, class `AvoidUnusedAssignmentRule` at line 1116)
Severity: False positive — Medium/High. The flagged assignment resets state a **later, separate invocation** of the same closure reads; the rule's dataflow model has no notion of "declared once, invoked repeatedly."
Rule version: v3 | Since/Updated: **not found in source** — the doc comment immediately preceding `class AvoidUnusedAssignmentRule` (`code_quality_variables_rules.dart:1106-1115`) describes a different rule ("Warns when accessing collection elements by constant index in a loop", `Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5`) and does not match this rule's actual behavior or its `{v3}` LintCode suffix — this looks like a doc-comment/rule mismatch in the source itself, not a value worth citing.

Rule source unchanged between v16.2.1 and 16.3.0 (HEAD); line numbers cite HEAD (checkout at `9456b83e`, `v16.2.1-13-g9456b83e`).

---

## Summary

`avoid_unused_assignment` reports *"Variable is assigned a value that is never read before being overwritten or going out of scope"* on `fieldWasQuoted = false;` inside a local closure `endField()` in `saropa_drift_advisor/lib/src/drift_debug_import.dart`'s `parseCsvLines`. The assignment resets state captured from the enclosing function that is read on the **next call** to `endField()` (via `row.add(fieldWasQuoted ? fieldRaw : fieldRaw.trim())`) and by a sibling closure `endRow()`'s blank-line check — both closures are invoked repeatedly from a character-scanning `while` loop. The rule treats the block containing the closures' declarations as if all statements inside every nested closure execute once, in a single top-to-bottom pass, and compares assignments to the same variable name by **source order** rather than by any notion of "these two writes belong to different function invocations."

---

## Attribution Evidence

```bash
$ grep -rn "'avoid_unused_assignment'" lib/src/rules/
lib/src/rules/code_quality/code_quality_variables_rules.dart:1123:    'avoid_unused_assignment',

$ grep -rn "'avoid_unused_assignment'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# 0 matches
```

**Emitter registration:** `lib/saropa_lints.dart:674` — `AvoidUnusedAssignmentRule.new,`
**Rule class:** `AvoidUnusedAssignmentRule` — defined `lib/src/rules/code_quality/code_quality_variables_rules.dart:1116`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

Minimal reduction of `saropa_drift_advisor/lib/src/drift_debug_import.dart:261-322` (`parseCsvLines`):

```dart
List<List<String>> parseCsvLines(String csv) {
  final row = <String>[];
  var fieldWasQuoted = false;

  void endField() {
    row.add(fieldWasQuoted ? 'quoted' : 'plain');
    // LINT (false positive): resets closure-captured state that the NEXT
    // call to endField() reads via the ternary above — not dead within a
    // single call, but the rule's dataflow analysis is single-invocation.
    fieldWasQuoted = false;
  }

  var i = 0;
  while (i < csv.length) {
    if (csv[i] == '"') {
      fieldWasQuoted = true; // this write is what the rule compares against
    } else if (csv[i] == ',') {
      endField(); // calls the closure repeatedly — each call reads the
                   // PREVIOUS call's `fieldWasQuoted = false;`
    }
    i++;
  }
  return [row];
}
```

**Frequency:** Always, for a local variable captured by a closure that both reads and writes it, when the closure is invoked more than once and another (unrelated, textually-later) write to the same variable name exists elsewhere in the enclosing block.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the write is read on the next invocation of the closure that contains it |
| **Actual** | `[avoid_unused_assignment] Variable is assigned a value that is never read before being overwritten or going out of scope...` reported on `fieldWasQuoted = false;` inside `endField()` |

---

## AST Context

```
MethodDeclaration (parseCsvLines)
  └─ BlockFunctionBody
      └─ Block                                         ← context.addBlock fires here
          ├─ VariableDeclarationStatement (var fieldWasQuoted = false;)
          ├─ FunctionDeclarationStatement (void endField() { ... })
          │   └─ FunctionBody
          │       └─ Block
          │           ├─ ExpressionStatement (row.add(...ternary reading fieldWasQuoted...);)
          │           └─ ExpressionStatement (fieldWasQuoted = false;)   ← node reported here
          └─ WhileStatement
              └─ Block
                  └─ IfStatement (chain)
                      └─ Block
                          └─ ExpressionStatement (fieldWasQuoted = true;)  ← compared against, by source order
```

---

## Root Cause

`runWithReporter` (`code_quality_variables_rules.dart:1131-1168`) registers on `Block` and, per block, runs `_AssignmentUsageVisitor` (`code_quality_variables_rules.dart:1262-1288`) to collect every `AssignmentExpression` to each simple-identifier variable, **in AST/source order**, via `RecursiveAstVisitor.visitAssignmentExpression`. Two specific gaps combine to produce this false positive:

1. **`_AssignmentUsageVisitor` does not stop at nested closures.** Unlike its sibling `_ReturnCollector` in the same file (`code_quality_variables_rules.dart:1088-1104`), which explicitly overrides `visitFunctionExpression` to skip descending into nested functions ("Don't descend into nested functions"), `_AssignmentUsageVisitor` (`code_quality_variables_rules.dart:1262-1288`) has no such override. It recurses fully into `endField()`'s closure body, so the assignment inside that closure is collected into the *same* `assignments['fieldWasQuoted']` list as the assignment inside the `while` loop several statements later — as if both occur once, in a single linear pass of the outer block, rather than in two separately-invoked functions.

2. **`_isInsideLoop` stops at the nearest enclosing `FunctionBody`, so it never "sees through" a closure back to its call site's loop.** `_isInsideLoop` (`code_quality_variables_rules.dart:1177-1190`) walks `node.parent` upward looking for `WhileStatement`/`DoStatement`/`ForStatement`, but breaks immediately on hitting a `FunctionBody` (line 1186). Walking up from `fieldWasQuoted = false;` inside `endField()`'s body hits `endField`'s own `FunctionBody` first — `endField`'s *declaration* is a sibling statement before the `while` loop, not nested inside it — so the walk terminates and returns `false`, even though `endField()` is in fact *called* from inside the loop (`endField();` inside the `while`/`if` chain further down). The rule has no call-graph/invocation-count model at all; it only recognizes "inside a loop" when the assignment is lexically nested inside a loop body, not when it's inside a function that is *called from* a loop.

With both guards defeated, `_canMoveCloser`'s siblings in `runWithReporter` (`code_quality_variables_rules.dart:1141-1165`) walk the two collected assignments — `fieldWasQuoted = false;` (inside `endField`, textually first) and `fieldWasQuoted = true;` (inside the `while`/`if` chain, textually second) — and none of the remaining guards (`_isInsideConditionalOnly`, `_nextAssignmentReadsVariable`, `_areInOppositeBranches`, all `code_quality_variables_rules.dart:1194-1238`) recognize that the two assignments live in entirely different, repeatedly-and-independently-invoked functions, so `reporter.atNode(current, code)` fires on the closure's assignment.

---

## Suggested Fix

Give `_AssignmentUsageVisitor` (`code_quality_variables_rules.dart:1262-1288`) the same nested-function boundary that `_ReturnCollector` already has: track assignments **per enclosing function scope** (top-level block, or each `FunctionExpression`/`FunctionDeclarationStatement` body found along the way) rather than merging every nested closure's assignments into one flat, source-ordered list keyed only by variable name. When a variable is captured by a local function/closure and both read and written inside that closure's own body, and that closure's call sites are reachable from a loop (or the closure could otherwise be invoked more than once, e.g. it's also passed as a callback), treat the closure's own write as live across separate invocations instead of flagging it against an unrelated assignment that merely happens to appear later in the source text of the enclosing block.

---

## Fixture Gap

The fixture at `example/lib/code_quality/avoid_unused_assignment_fixture.dart` has no case involving a local closure at all (confirmed: no reference to closures, nested `void` local functions, or repeated-invocation state in that file — only a single flat `_bad188_foo`/`_good153`-style pair, lines 110-118). It should add:

1. **Variable captured and reset by a local closure invoked from a loop, read on the closure's own next invocation** — expect NO LINT (this report's exact shape: `endField()` reading then resetting `fieldWasQuoted`, called repeatedly from a `while` loop).
2. A contrasting **variable assigned twice in the same closure invocation, with the first write genuinely dead** — expect LINT, to confirm the fix's closure-scoping doesn't over-suppress real same-invocation dead writes.

---

## Changes Made

_Not yet — open report._

---

## Tests Added

_Not yet — open report._

---

## Commits

_Not yet — open report._

---

## Finish Report (2026-09-18)

**Verdict: Valid.** The report's root-cause analysis was accurate and its suggested fix was implemented essentially as described.

**Root cause:** `_AssignmentUsageVisitor` (`lib/src/rules/code_quality/code_quality_variables_rules.dart`) is a `RecursiveAstVisitor` with no boundary at nested closures, unlike its sibling `_ReturnCollector` in the same file, which already overrides `visitFunctionExpression` to stop descending. When `runWithReporter`'s `context.addBlock` callback ran on the *outer* block (containing both the local closure's declaration and the later `while` loop), the visitor recursed straight into the closure body and merged its internal `fieldWasQuoted = false;` assignment into the same flat, source-ordered `assignments['fieldWasQuoted']` list as the unrelated `fieldWasQuoted = true;` write inside the loop several statements later. The rule then compared these two assignments as if they were sequential writes in one linear execution, with no model of "these live in separately-and-repeatedly invoked functions."

**Fix:** Added a `visitFunctionExpression` override to `_AssignmentUsageVisitor` that skips descent into nested closures, mirroring `_ReturnCollector`'s existing pattern:

```dart
// Don't descend into nested closures/local functions: a closure may be
// invoked repeatedly (e.g. from a loop at its call site), so an
// assignment inside it that resets state for the closure's OWN next
// invocation is not dead relative to unrelated assignments elsewhere in
// the enclosing block's single top-to-bottom source order. Each nested
// function body is a separate `Block` and gets its own independent
// `addBlock` pass (see runWithReporter), so genuine same-invocation dead
// writes inside the closure are still caught there.
@override
void visitFunctionExpression(FunctionExpression node) {
  // Skip
}
```

This is safe because `context.addBlock` fires independently for *every* `Block` node in the AST (confirmed via `lib/src/native/saropa_context.dart` / `lib/src/scan/capturing_registry.dart`), including a closure's own body block. So a genuinely dead write made and immediately overwritten within a single invocation of a closure is still caught when the analyzer visits that closure's own block directly — only the incorrect cross-scope merge (outer block's pass recursing into the closure) is eliminated.

**Files changed:**
- `lib/src/rules/code_quality/code_quality_variables_rules.dart` — added the `visitFunctionExpression` override to `_AssignmentUsageVisitor` (~15 lines).
- `example/lib/code_quality/avoid_unused_assignment_fixture.dart` — added `_good189ParseCsvLines` (closure-captured reset read by the closure's own next invocation, called from a `while` loop — matches the report's reproducer; expects NO lint) and `_bad189`/`inner()` (a genuinely dead write inside a closure, same invocation; expects LINT), per the report's "Fixture Gap" section.
- `test/rules/code_quality/avoid_unused_assignment_fixture_test.dart` — new resolved-analyzer test file (package had no dedicated fixture test for this rule previously) covering: same-invocation dead write fires; read-afterward does not fire; the closure-capture regression case does not fire; the same-invocation dead write inside a closure still fires.

**Correction (post-compile verification):** once the tree compiled cleanly (the concurrent-edit breakage below had landed), the two true-positive cases as first written — `var count = 1; count = 2;` and `var total = 1; total = 2;` — did NOT fire. Traced to pre-existing, out-of-scope behavior: `_AssignmentUsageVisitor` only records `AssignmentExpression` nodes, never a `VariableDeclaration`'s initializer, so a declare-with-initial-value-then-reassign-once pair never reaches the `entry.value.length > 1` comparison in `runWithReporter` — there's only one recorded assignment to compare. This is not something the closure fix touches or should touch (widening the visitor to track initializers is out of scope and could introduce new false positives). Both true-positive test cases and the `_bad189` fixture were rewritten to a shape the rule actually flags today — two plain reassignments with no intervening read, e.g. `var total = 0; total = 1; total = 2;` — with the rule correctly flagging the *first* reassignment (`total = 1`) as dead since it's overwritten by `total = 2` before being read. One of the two true-positive cases stays inside a closure to keep proving same-invocation dead writes inside closures are still caught after the fix. The closure-capture regression test itself (the report's exact repro) required no change and passed throughout.

**Tests:** `dart analyze` on all three touched files: clean, "No issues found!". `dart test test/rules/code_quality/avoid_unused_assignment_fixture_test.dart`: all 4 tests pass:
```
AvoidUnusedAssignmentRule - resolved fires on a same-invocation dead write
AvoidUnusedAssignmentRule - resolved does NOT fire when the write is read afterward
AvoidUnusedAssignmentRule - resolved does NOT fire on closure-captured variable reset read by the closure's own next invocation
AvoidUnusedAssignmentRule - resolved fires on a genuinely dead write inside a closure (same invocation)
All tests passed!
```
(Earlier in this task, the run was transiently blocked by unrelated, concurrently in-progress edits from other agents to `lib/src/rules/platforms/windows_rules.dart` and `lib/src/rules/code_quality/code_quality_avoid_rules.dart` — both have since compiled cleanly.)

---

## Environment

- saropa_lints version: 16.2.1 resolved (checkout under investigation: `9456b83e`, `v16.2.1-13-g9456b83e`; rule source unchanged since v16.2.1)
- Dart SDK version: 3.12.2 (stable)
- custom_lint version: n/a — findings from `saropa_lints scan` CLI / VS Code extension
- Triggering project/file: `saropa_drift_advisor` 4.4.1 — `lib/src/drift_debug_import.dart:261-322` (`parseCsvLines`/`endField`). Scan report: `saropa_drift_advisor/reports/20260918/20260918_081229_findings.json`
