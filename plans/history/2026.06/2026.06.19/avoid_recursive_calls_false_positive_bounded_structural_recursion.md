# BUG: `avoid_recursive_calls` — Fires on bounded, base-case-guarded structural recursion (depth-first JSON normalization)

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-19
Rule: `avoid_recursive_calls`
File: `lib/src/rules/code_quality/code_quality_avoid_rules.dart` (line ~614)
Severity: False positive / High
Rule version: v5 | Since: v0.1.4 | Updated: v4.13.0

---

## Summary

`avoid_recursive_calls` fires on any direct self-call, including correct, idiomatic recursion that plainly has terminating base cases and recurses only to walk a bounded, finite data structure (depth-first JSON normalization). The diagnostic message warns about "unbounded recursion [that] exhausts the call stack ... Verify a terminating base case exists" — but the rule performs no base-case or depth analysis at all. It reports the mere presence of a self-call.

Expected: no diagnostic when terminating base cases exist and depth is bounded by finite input. Actual: the lint fires on every direct recursive call.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_recursive_calls'" lib/src/rules/
# lib/src/rules/code_quality/code_quality_avoid_rules.dart:615:    'avoid_recursive_calls',

# Negative — rule is NOT defined in the triggering sibling project
grep -rn "avoid_recursive_calls" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# 0 matches (the name appears only in that project's analysis_options.yaml, as a consumer)
```

**Emitter registration:** `lib/src/rules/code_quality/code_quality_avoid_rules.dart:615`
**Rule class:** `AvoidRecursiveCallsRule` — registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` (saropa_lints custom_lint plugin)

---

## Reproducer

From `saropa_drift_advisor/lib/src/dvr_bindings.dart` — a depth-first JSON normalizer with three terminating base cases. Recursion depth is bounded by the finite nesting of the input.

```dart
Object? normalizeDvrJsonValue(Object? value) {
  if (value == null || value is bool || value is num) return value; // base case
  if (value is String) return value;                                  // base case
  if (value is List) {
    return value
        .map((e) => normalizeDvrJsonValue(e as Object?)) // LINT avoid_recursive_calls — but bounded structural recursion, should NOT lint
        .toList(growable: false);
  }
  if (value is Map) {
    final out = <String, Object?>{};
    for (final e in value.entries) {
      out['${e.key}'] = normalizeDvrJsonValue(e.value as Object?); // LINT — same, should NOT lint
    }
    return out;
  }
  return '[unsupported:${value.runtimeType}]'; // base case
}
```

Expected: NO diagnostic. Multiple terminating base cases exist (`null`/`bool`/`num`, `String`, and the unsupported fallthrough all `return` without recursing) and recursion depth is bounded by the finite nesting of the input. Converting this to an explicit stack would be strictly worse — more code, more state, no correctness gain.

Actual: `[avoid_recursive_calls]` fires on both recursive call sites.

**Frequency:** Always — on any direct recursive call, regardless of whether base cases exist.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the function has multiple terminating base cases and bounded recursion depth |
| **Actual** | `[avoid_recursive_calls] Function contains a direct recursive call to itself. ...` reported on each self-call inside the `List` and `Map` branches |

---

## AST Context

The rule registers on `FunctionDeclaration` / `MethodDeclaration`, then walks the whole body with a `RecursiveAstVisitor` (`_RecursiveCallVisitor`) and reports any invocation whose name matches the enclosing function name.

```
FunctionDeclaration (normalizeDvrJsonValue)
  └─ FunctionExpression
      └─ BlockFunctionBody
          └─ Block
              ├─ IfStatement (value is List)
              │   └─ ReturnStatement
              │       └─ MethodInvocation (.map(...).toList(...))
              │           └─ FunctionExpression  (e) => normalizeDvrJsonValue(e as Object?)
              │               └─ MethodInvocation (normalizeDvrJsonValue)  ← reported here
              └─ IfStatement (value is Map)
                  └─ ... AssignmentExpression
                      └─ MethodInvocation (normalizeDvrJsonValue)         ← reported here
```

The reported node is the self-call `MethodInvocation`. The rule never inspects the sibling base-case `IfStatement`/`ReturnStatement` nodes that guarantee termination.

---

## Root Cause

The rule is a pure name-match self-call detector with **no base-case or depth analysis**. The diagnostic message asserts a property ("unbounded recursion", "Verify a terminating base case exists") the rule never checks.

**Detection flow (lines 622–679):**

`runWithReporter` (lines 622–640) registers two callbacks — `addFunctionDeclaration` and `addMethodDeclaration` — and for each calls `_checkBodyForRecursion(body, name, reporter)` (lines 642–653). That constructs a `_RecursiveCallVisitor` with the enclosing function/method name and accepts it over the body.

`_RecursiveCallVisitor` (lines 656–679) does exactly two things:

- `visitMethodInvocation` (lines 663–669): if `node.methodName.name == functionName && node.realTarget == null`, it calls `reporter.atNode(node)`. The only guard is "unqualified call whose name equals the enclosing function name."
- `visitFunctionExpressionInvocation` (lines 671–678): if the called function is a `SimpleIdentifier` matching `functionName`, it reports.

There is no examination of:

- whether a non-recursive `return` / `throw` / `break` path exists before the recursive call (a base case),
- whether the recursion is guarded by a conditional that narrows the input toward a terminating case,
- whether the recursion walks a bounded structure (the depth is a property of the input, not statically knowable here),
- the resolved element of the call (it matches on `methodName.name` / identifier text, not `staticElement`, so a same-named but unrelated function would also match — a separate soundness gap, not the subject of this report).

The mechanism is therefore "report every direct self-call." Because correct recursion (tree/JSON walks, divide-and-conquer, parser descent) is common and idiomatic, this is a high-volume false positive on correct code, and the correction advice ("convert to an iterative approach using a loop or explicit stack") is actively harmful for clean structural recursion.

### Hypothesis A: rule reports the mere presence of a self-call

Confirmed by reading the source. `_RecursiveCallVisitor` reports on name match alone (lines 665, 674). No control-flow or base-case analysis exists anywhere in the class. This is the root cause.

### Hypothesis B: the message overstates what the rule detects

Confirmed. The `LintCode` message (line 616) and correction (lines 617–618) claim the rule has identified *unbounded* recursion lacking a base case. The rule cannot distinguish bounded from unbounded recursion. The message describes a check the code does not perform.

---

## Suggested Fix

Statically deciding whether recursion is "unbounded" is undecidable in general (it depends on runtime input and arbitrary control flow), so the rule cannot soundly do what its message claims. Honest options, lightest first:

1. **Down-tier / opt-in (recommended).** Because correct recursion is common, this rule produces noise on healthy code more often than it catches a real defect. Make it off-by-default — drop it from the default tier set in `tiers.dart` and require explicit opt-in. This stops the false positives without any unsound heuristic. Lowest risk, no detection logic to get wrong.

2. **Skip functions that contain an early-return base case guarding the recursive branch (cheap heuristic).** Before reporting in `_RecursiveCallVisitor` (lines 663–678), have `_checkBodyForRecursion` (lines 642–653) first scan the body for at least one `ReturnStatement` / `ThrowExpression` / `BreakStatement` reachable on a non-recursive path (e.g. inside an `IfStatement` whose body returns without a self-call). If such a base-case path exists, suppress the diagnostic for that body. This recognizes the common, correct shape (guard clauses then recurse) and silences the reproducer above. It is a heuristic, not a proof — it can still miss pathological cases — but it removes the dominant false-positive class. Note: it will also suppress some genuinely-unbounded recursion that happens to contain an unrelated early `return`; that trade-off favors correct code, which is the right default for a warning-tier rule.

3. **Narrow to "no reachable base case" only (hard, not recommended).** Only flag self-calls when *no* non-recursive terminating path exists before the call. This is the strongest version but is hard to implement soundly (requires real reachability analysis over the control-flow graph) and still cannot certify boundedness. Most of the effort, most of the remaining unsoundness.

In all cases, **fix the message to match what the rule actually verifies.** The current text (line 616–618) promises a base-case verification the rule does not perform; even option 1 should soften the message to "Direct recursive call detected — confirm termination" rather than asserting "unbounded recursion ... Verify a terminating base case exists."

Recommendation: option 1 (down-tier to opt-in) as the immediate fix, optionally combined with option 2's base-case-guard skip if the rule stays on by default.

---

## Fixture Gap

The fixture at `example*/lib/code_quality/avoid_recursive_calls_fixture.dart` should include:

1. **Bounded structural recursion with base cases** (the JSON-normalizer shape above) — expect NO lint
2. **Tree/AST walk: recurse over `node.children`** with an empty-children base case — expect NO lint
3. **Divide-and-conquer with a size guard** (`if (lo >= hi) return;` then two recursive halves) — expect NO lint
4. **Genuinely unguarded self-call** (`int f(int n) => n * f(n - 1);` with no base case) — expect LINT (the one case the rule should keep)
5. **Self-call inside a closure passed to `.map(...)`** — confirm the `FunctionExpressionInvocation` / `MethodInvocation`-in-lambda path is exercised

---

## Changes Made

Implemented **option 2** (base-case-guard skip) plus the message fix, rather than option 1 (down-tier). Reason: the rule's own documented "good" example is base-case-guarded recursion (`if (n <= 1) return 1;`), so the rule already *intends* to flag only unguarded recursion — the faithful fix makes the implementation match the docs and the message, keeping the rule's value on by default. It stays in `professionalOnlyRules` where it already lived.

`lib/src/rules/code_quality/code_quality_avoid_rules.dart`:

- `_checkBodyForRecursion` now runs a `_BaseCaseVisitor` over the body first and suppresses all diagnostics for that body when a terminating base case is detected.
- `_BaseCaseVisitor` recognizes three base-case shapes (all heuristics that favor correct code):
  1. a recursion-free `return`/`throw` guarded by a conditional (`if`/`switch`) — the guard-clause-then-recurse idiom and the JSON-normalizer's type checks;
  2. a ternary whose non-recursive branch terminates (`n <= 1 ? 1 : n * f(n - 1)`);
  3. every direct self-call sitting inside a loop (`for`/`while`/`do`) — iteration over a finite collection bounds the recursion (tree/graph walks); the empty-collection case is the implicit base case.
  It does not descend into nested closures, so a guarded return inside a callback cannot mask outer unbounded recursion.
- Self-call matching factored into a shared `_isSelfCall` / `_containsSelfCall` so the reporter and the base-case detector cannot drift.
- Message rewritten to state what the rule actually checks ("no detected terminating base case") instead of asserting it verified unbounded recursion. Correction message and DartDoc updated; rule version bumped v5 → v6.

Heuristic trade-off (documented in the rule's DartDoc): boundedness is undecidable, so this can miss genuinely-unbounded recursion that happens to contain an unrelated guard clause or a self-call inside an infinite loop (`while (true) { f(); }`). That trade favors correct code, the right default for an INFO/warning-tier rule.

Verified with the scan CLI (`dart run saropa_lints scan <dir> --tier comprehensive --format json`): only the two genuinely-unguarded cases (`=> n * f(n - 1)` and the block-body equivalent) fire; the JSON normalizer, factorial-with-guard, ternary, tree walk, and divide-and-conquer are all silent.

---

## Tests Added

`example/lib/code_quality/avoid_recursive_calls_fixture.dart` rewritten. The prior fixture was invalid: both its "bad" and "good" cases called `factorial(n-1)` — a *different* name than the enclosing function — so the name-match rule never fired on either, and the `expect_lint` had never been validated. New fixture covers:

1. Unguarded expression-body self-call — expect LINT
2. Unguarded block-body self-call — expect LINT
3. Guard-clause factorial — expect NO lint
4. Ternary base case — expect NO lint
5. Bounded JSON normalizer (the reproducer; self-call inside a `.map` closure and a `Map` loop) — expect NO lint
6. Tree walk over `node.children` (loop-bounded) — expect NO lint
7. Divide-and-conquer with size guard — expect NO lint

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: 14.0.3
- Dart SDK version: 3.12.1
- custom_lint version: via CLI
- Triggering project/file: `saropa_drift_advisor` — `lib/src/dvr_bindings.dart` (`normalizeDvrJsonValue`)

---

## Finish Report (2026-06-19)

### Defect

`avoid_recursive_calls` was a pure name-match self-call detector with no base-case or depth analysis. It reported every direct recursive call, including correct, idiomatic recursion that plainly terminates — guard-clause-then-recurse, ternary base cases, divide-and-conquer, and structural walks of finite data. The diagnostic text asserted a property ("unbounded recursion ... Verify a terminating base case exists") the rule never checked, and its correction advice (convert to a loop/explicit stack) is actively harmful for clean structural recursion. The rule's own documented "good" example (factorial with `if (n <= 1) return 1;`) was itself flagged.

### Resolution

Option 2 from the report (base-case-guard skip) plus the message fix, rather than option 1 (down-tier). The rule already intended to flag only unguarded recursion — its documentation says so — so the faithful fix aligns the implementation with the docs and message and preserves the rule's value on by default. It remains in `professionalOnlyRules`.

In `lib/src/rules/code_quality/code_quality_avoid_rules.dart`, `_checkBodyForRecursion` now runs `_BaseCaseVisitor` over the body and suppresses all diagnostics for that body when a terminating base case is detected. Three base-case shapes are recognized, all heuristics that favor correct code:

1. a recursion-free `return`/`throw` guarded by an `if`/`switch`;
2. a ternary whose non-recursive branch terminates;
3. every direct self-call nested inside a `for`/`while`/`do` loop (iteration over a finite collection bounds the recursion; the empty-collection case is the implicit base case).

`_BaseCaseVisitor` does not descend into nested closures, so a guarded return inside a callback cannot mask outer unbounded recursion. Self-call matching was factored into shared `_isSelfCall` / `_containsSelfCall` helpers so the reporter and the base-case detector cannot diverge. The `LintCode` message, correction message, and DartDoc were rewritten to state what the rule actually verifies; rule version bumped v5 → v6.

Boundedness is undecidable, so the heuristic can miss genuinely-unbounded recursion that contains an unrelated guard clause or a self-call inside an infinite loop. That trade favors correct code, the right default for an INFO-tier rule, and is documented in the rule's DartDoc.

### Verification

`example/lib/code_quality/avoid_recursive_calls_fixture.dart` was rewritten. The prior fixture was invalid: its "bad" and "good" cases both called `factorial(n-1)` — a different name than the enclosing function — so the name-match rule never fired and the `expect_lint` had never been validated. The new fixture covers unguarded expression/block bodies (LINT), guard-clause and ternary factorials, the JSON normalizer reproducer, a loop-bounded tree walk, and divide-and-conquer (all NO lint).

`test/rules/code_quality/avoid_recursive_calls_fp_test.dart` adds seven oracle-backed regression tests over the resolved-rule harness; all pass. The scan CLI on the same inputs reports the rule only on the two genuinely-unguarded cases. Scoped `dart analyze --fatal-infos` on the changed rule file is clean.
